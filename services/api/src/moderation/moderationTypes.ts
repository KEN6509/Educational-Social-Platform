export const MODERATION_PROMPT_VERSION = 'cyanzone-moderation-v4';

export type ModerationTargetType = 'post' | 'comment';
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
  overallRiskScore: number;
  evidence: string[];
  userReason: string;
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

export function normalizeModerationScore(score: number): number {
  // Shift the decimal exponent so midpoint values such as 39.995 round correctly.
  const [mantissa, exponent = '0'] = score.toString().split('e');
  return Math.round(Number(`${mantissa}e${Number(exponent) + 2}`)) / 100;
}

export function decideModeration(overallRiskScore: number): ModerationDecision {
  return overallRiskScore < 40
    ? 'approved'
    : overallRiskScore <= 60
      ? 'admin_review'
      : 'rejected';
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

  constructor(
    ratings: unknown = undefined,
    providerAttempts?: number,
  ) {
    super('Gemini blocked the moderation input for safety reasons', {
      retryable: false,
      providerAttempts,
    });
    this.name = 'GeminiInputSafetyError';
    this.ratings = ratings;
  }
}
