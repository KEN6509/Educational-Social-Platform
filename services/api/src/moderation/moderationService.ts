import {
  GeminiInputSafetyError,
  MODERATION_PROMPT_VERSION,
  MODERATION_CATEGORIES,
  decideModeration,
  ModerationProviderError,
  type ModerationCategory,
  type ModerationCase,
  type ModerationEvidenceSource,
  type ModerationProvider,
  type ModerationProviderResult,
  type ModerationRepository,
  type ModerationTarget,
  type ModerationTargetType,
  type PersistedModerationResult,
} from './moderationTypes.js';
import type { MemberIdentity } from './moderationAuth.js';

export type ModerationResponse = {
  targetType: ModerationTargetType;
  targetId: string;
  moderationRevision: number;
  status: 'pending' | 'approved' | 'rejected';
  caseState: ModerationCase['state'];
  riskScore: number | null;
  reason: string | null;
  retryAllowed: boolean;
};

export interface ModerationService {
  moderate(
    type: ModerationTargetType,
    id: string,
    member: MemberIdentity,
  ): Promise<ModerationResponse>;
}

export class ModerationServiceError extends Error {
  constructor(
    message: string,
    public readonly status: 403 | 404 | 409 | 429 | 500,
  ) {
    super(message);
    this.name = 'ModerationServiceError';
  }
}

export class ModerationNotFoundError extends ModerationServiceError {
  constructor(message = 'Moderation target not found.') {
    super(message, 404);
    this.name = 'ModerationNotFoundError';
  }
}

export class ModerationOwnershipError extends ModerationServiceError {
  constructor(message = 'You can only moderate your own content.') {
    super(message, 403);
    this.name = 'ModerationOwnershipError';
  }
}

export class ModerationCooldownError extends ModerationServiceError {
  constructor(message = 'Please wait before retrying moderation.') {
    super(message, 429);
    this.name = 'ModerationCooldownError';
  }
}

export class ModerationStaleError extends ModerationServiceError {
  constructor(message = 'The content changed while it was being moderated.') {
    super(message, 409);
    this.name = 'ModerationStaleError';
  }
}

export class ModerationProviderFailureError extends Error {
  readonly status = 503 as const;
  readonly retryAllowed: boolean;

  constructor(message = 'Moderation is temporarily unavailable.', retryAllowed = true) {
    super(message);
    this.name = 'ModerationProviderFailureError';
    this.retryAllowed = retryAllowed;
  }
}

export function createModerationService(
  repository: ModerationRepository,
  provider: ModerationProvider,
): ModerationService {
  return {
    async moderate(type, id, member) {
      const target = await repository.loadTarget(type, id);
      if (!target) throw new ModerationNotFoundError();
      if (target.ownerId !== member.id) throw new ModerationOwnershipError();

      let moderationCase: ModerationCase;
      try {
        moderationCase = await repository.prepare(type, id, member.id);
      } catch (error) {
        if (isCooldownError(error)) throw new ModerationCooldownError();
        if (isStaleError(error)) throw new ModerationStaleError();
        throw error;
      }

      if (
        moderationCase.state !== 'processing' ||
        moderationCase.shouldProcess === false
      ) {
        return toResponse(moderationCase);
      }

      try {
        const providerResult = await provider.moderate(target.target);
        const state = decideModeration(providerResult);
        return await applyResult(
          repository,
          moderationCase,
          state,
          providerResult,
          providerResult.providerAttempts ?? 1,
        );
      } catch (error) {
        if (error instanceof GeminiInputSafetyError) {
          const safetyResult = createSafetyResult(error, target.target);
          return await applyResult(
            repository,
            moderationCase,
            'rejected',
            safetyResult,
            error.providerAttempts,
          );
        }
        if (!(error instanceof ModerationProviderError)) throw error;

        try {
          await repository.markFailed(moderationCase.id, moderationCase.revision, {
            claimToken: moderationCase.claimToken ?? '',
            code: error.retryable ? 'provider_unavailable' : 'provider_rejected',
            message: 'Gemini moderation did not complete.',
            attemptCount: error.providerAttempts,
          });
        } catch (markFailedError) {
          if (isStaleError(markFailedError)) throw new ModerationStaleError();
          throw markFailedError;
        }

        throw new ModerationProviderFailureError(
          'Moderation is temporarily unavailable. Please try again.',
          error.retryable,
        );
      }
    },
  };
}

async function applyResult(
  repository: ModerationRepository,
  moderationCase: ModerationCase,
  state: Exclude<ModerationCase['state'], 'processing' | 'failed' | 'superseded'>,
  providerResult: ModerationProviderResult,
  attemptCount: number,
): Promise<ModerationResponse> {
  const result: PersistedModerationResult = {
    ...providerResult,
    state,
    claimToken: moderationCase.claimToken ?? '',
    attemptCount,
  };
  try {
    const applied = await repository.applyResult(
      moderationCase.id,
      moderationCase.revision,
      result,
    );
    return toResponse(applied);
  } catch (error) {
    if (isStaleError(error)) throw new ModerationStaleError();
    throw error;
  }
}

function createSafetyResult(
  error: GeminiInputSafetyError,
  target: ModerationTarget,
): ModerationProviderResult {
  const categoryScores = Object.fromEntries(
    MODERATION_CATEGORIES.map((category) => [category, 0]),
  ) as Record<ModerationCategory, number>;
  const blockedCategories: ModerationCategory[] = [];

  if (Array.isArray(error.ratings)) {
    for (const rating of error.ratings) {
      if (rating == null || typeof rating !== 'object') continue;
      const details = rating as Record<string, unknown>;
      const category = mapGeminiSafetyCategory(details.category);
      if (!category) continue;
      const score = safetyRatingScore(details);
      categoryScores[category] = Math.max(categoryScores[category], score);
      if (details.blocked === true) blockedCategories.push(category);
    }
  }

  const evidenceSource: ModerationEvidenceSource = error.evidenceSource ??
    (target.images.length > 0 ? 'both' : 'text');
  const categoryLabel = blockedCategories.length > 0
    ? ` (${[...new Set(blockedCategories)].join(', ')})`
    : '';
  return {
    recommendedDecision: 'rejected',
    overallRiskScore: 100,
    categoryScores,
    evidence: [`Gemini blocked the input under its safety policy${categoryLabel}.`],
    userReason: 'This content could not be cleared by automated safety checks.',
    evidenceSource,
    model: 'gemini-safety-policy',
    promptVersion: MODERATION_PROMPT_VERSION,
    providerAttempts: error.providerAttempts,
  };
}

function mapGeminiSafetyCategory(value: unknown): ModerationCategory | null {
  if (typeof value !== 'string') return null;
  const category = value.toUpperCase();
  if (category.includes('HARASSMENT') || category.includes('BULLY')) {
    return 'harassmentBullying';
  }
  if (category.includes('HATE')) return 'hate';
  if (category.includes('SEXUAL')) return 'sexual';
  if (category.includes('DANGEROUS') || category.includes('VIOLENCE')) {
    return 'violenceDanger';
  }
  if (category.includes('SELF_HARM') || category.includes('SELF-HARM')) {
    return 'selfHarm';
  }
  return null;
}

function safetyRatingScore(rating: Record<string, unknown>): number {
  if (rating.blocked === true) return 100;
  if (typeof rating.probabilityScore === 'number') {
    const raw = rating.probabilityScore;
    return Math.max(0, Math.min(100, raw <= 1 ? raw * 100 : raw));
  }
  const probability = typeof rating.probability === 'string'
    ? rating.probability.toUpperCase()
    : '';
  return ({
    NEGLIGIBLE: 0,
    LOW: 25,
    MEDIUM: 50,
    HIGH: 75,
    VERY_HIGH: 100,
  } as Record<string, number>)[probability] ?? 0;
}

function toResponse(moderationCase: ModerationCase): ModerationResponse {
  return {
    targetType: moderationCase.targetType,
    targetId: moderationCase.targetId,
    moderationRevision: moderationCase.revision,
    status:
      moderationCase.state === 'approved'
        ? 'approved'
        : moderationCase.state === 'rejected'
          ? 'rejected'
          : 'pending',
    caseState: moderationCase.state,
    riskScore: moderationCase.riskScore ?? null,
    reason: moderationCase.reason ?? null,
    retryAllowed: moderationCase.state === 'failed',
  };
}

function isStaleError(error: unknown): boolean {
  return error instanceof ModerationServiceError && error.status === 409 ||
    (error instanceof Error && /stale|revision/i.test(error.message));
}

function isCooldownError(error: unknown): boolean {
  return error instanceof ModerationServiceError && error.status === 429 ||
    (error instanceof Error && /rate limited|retry.*temporarily/i.test(error.message));
}
