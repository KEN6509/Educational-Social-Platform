export const MODERATION_PROMPT_VERSION = 'cyanzone-moderation-v2';

export const MODERATION_CATEGORIES = [
  'harassmentBullying',
  'hate',
  'sexual',
  'violenceDanger',
  'selfHarm',
  'spamScam',
  'privacyExposure',
] as const;

export type ModerationCategory = (typeof MODERATION_CATEGORIES)[number];
export type ModerationTargetType = 'post' | 'comment';
export type ModerationEvidenceSource = 'text' | 'image' | 'both';
export type SupportedImageMimeType =
  | 'image/png'
  | 'image/jpeg'
  | 'image/webp'
  | 'image/heic'
  | 'image/heif';

export type ModerationImage = {
  uri: string;
  mimeType: SupportedImageMimeType;
};

export type ModerationTarget = {
  targetType: ModerationTargetType;
  title?: string | null;
  content: string;
  tags: string[];
  images: ModerationImage[];
};

export type ModerationProviderResult = {
  recommendedDecision: ModerationDecision;
  overallRiskScore: number;
  categoryScores: Record<ModerationCategory, number>;
  evidence: string[];
  userReason: string;
  evidenceSource: ModerationEvidenceSource;
  model: string;
  promptVersion: string;
  providerAttempts?: number;
};

export type ModerationCaseState =
  | 'processing'
  | 'admin_review'
  | 'approved'
  | 'rejected'
  | 'failed'
  | 'superseded';

export type ModerationTargetRecord = {
  id: string;
  ownerId: string;
  revision: number;
  target: ModerationTarget;
};

export type ModerationCase = {
  id: string;
  targetType: ModerationTargetType;
  targetId: string;
  ownerId: string;
  revision: number;
  state: ModerationCaseState;
  claimToken: string | null;
  attemptCount: number;
  riskScore?: number | null;
  reason?: string | null;
  shouldProcess?: boolean;
};

export type PersistedModerationResult = ModerationProviderResult & {
  claimToken: string;
  state: Exclude<ModerationCaseState, 'processing' | 'failed' | 'superseded'>;
  attemptCount: number;
};

export type PersistedModerationFailure = {
  claimToken: string;
  code: string;
  message: string;
  attemptCount: number;
};

export interface ModerationRepository {
  loadTarget(
    type: ModerationTargetType,
    id: string,
  ): Promise<ModerationTargetRecord | null>;
  prepare(
    type: ModerationTargetType,
    id: string,
    ownerId: string,
  ): Promise<ModerationCase>;
  applyResult(
    caseId: string,
    revision: number,
    result: PersistedModerationResult,
  ): Promise<ModerationCase>;
  markFailed(
    caseId: string,
    revision: number,
    failure: PersistedModerationFailure,
  ): Promise<ModerationCase>;
}

export type ModerationDecision = 'approved' | 'admin_review' | 'rejected';

export function decideModeration(
  result: Pick<ModerationProviderResult, 'overallRiskScore' | 'recommendedDecision'>,
): ModerationDecision {
  const scoreDecision = result.overallRiskScore < 40
    ? 'approved'
    : result.overallRiskScore <= 60
      ? 'admin_review'
      : 'rejected';
  const severity: Record<ModerationDecision, number> = {
    approved: 0,
    admin_review: 1,
    rejected: 2,
  };
  return severity[result.recommendedDecision] > severity[scoreDecision]
    ? result.recommendedDecision
    : scoreDecision;
}

export interface ModerationProvider {
  moderate(target: ModerationTarget): Promise<ModerationProviderResult>;
}

export class ModerationProviderError extends Error {
  readonly retryable: boolean;
  readonly cause?: unknown;
  readonly statusCode?: number;
  readonly providerAttempts: number;

  constructor(
    message: string,
    options: {
      retryable?: boolean;
      cause?: unknown;
      statusCode?: number;
      providerAttempts?: number;
    } = {},
  ) {
    super(message);
    this.name = 'ModerationProviderError';
    this.retryable = options.retryable ?? true;
    this.cause = options.cause;
    this.statusCode = options.statusCode;
    this.providerAttempts = options.providerAttempts ?? 1;
  }
}

export class GeminiInputSafetyError extends ModerationProviderError {
  readonly ratings: unknown;
  readonly evidenceSource?: ModerationEvidenceSource;

  constructor(
    ratings: unknown = undefined,
    evidenceSource?: ModerationEvidenceSource,
    providerAttempts?: number,
  ) {
    super('Gemini blocked the moderation input for safety reasons', {
      retryable: false,
      providerAttempts,
    });
    this.name = 'GeminiInputSafetyError';
    this.ratings = ratings;
    this.evidenceSource = evidenceSource;
  }
}
