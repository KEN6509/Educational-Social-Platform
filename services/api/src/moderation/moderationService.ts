import {
  GeminiInputSafetyError,
  MODERATION_CATEGORIES,
  decideModeration,
  ModerationProviderError,
  type ModerationCase,
  type ModerationProvider,
  type ModerationProviderResult,
  type ModerationRepository,
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

      let lastProviderError: ModerationProviderError | undefined;
      for (let attempt = 1; attempt <= 2; attempt += 1) {
        try {
          const providerResult = await provider.moderate(target.target);
          const state = decideModeration(providerResult.overallRiskScore);
          return await applyResult(
            repository,
            moderationCase,
            state,
            providerResult,
            attempt,
          );
        } catch (error) {
          if (error instanceof GeminiInputSafetyError) {
            const safetyResult = createSafetyResult();
            return await applyResult(
              repository,
              moderationCase,
              'rejected',
              safetyResult,
              attempt,
            );
          }
          if (!(error instanceof ModerationProviderError)) throw error;
          lastProviderError = error;
          if (!error.retryable || attempt === 2) break;
        }
      }

      try {
        await repository.markFailed(moderationCase.id, moderationCase.revision, {
          claimToken: moderationCase.claimToken ?? '',
          code: lastProviderError?.retryable ? 'provider_unavailable' : 'provider_rejected',
          message: 'Gemini moderation did not complete.',
          attemptCount: lastProviderError?.retryable ? 2 : 1,
        });
      } catch (error) {
        if (isStaleError(error)) throw new ModerationStaleError();
        throw error;
      }

      throw new ModerationProviderFailureError(
        'Moderation is temporarily unavailable. Please try again.',
        lastProviderError?.retryable ?? true,
      );
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

function createSafetyResult(): ModerationProviderResult {
  return {
    overallRiskScore: 100,
    categoryScores: Object.fromEntries(
      MODERATION_CATEGORIES.map((category) => [category, 100]),
    ) as Record<(typeof MODERATION_CATEGORIES)[number], number>,
    evidence: ['Gemini blocked the input under its safety policy.'],
    userReason: 'This content could not be cleared by automated safety checks.',
    evidenceSource: 'text' as const,
    model: 'gemini-safety-policy',
    promptVersion: 'cyanzone-moderation-v1',
  };
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
