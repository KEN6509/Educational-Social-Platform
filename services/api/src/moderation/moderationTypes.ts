export const MODERATION_PROMPT_VERSION = 'cyanzone-moderation-v1';

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
  overallRiskScore: number;
  categoryScores: Record<ModerationCategory, number>;
  evidence: string[];
  userReason: string;
  evidenceSource: ModerationEvidenceSource;
  model: string;
  promptVersion: string;
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

export function decideModeration(score: number): ModerationDecision {
  if (score < 40) return 'approved';
  if (score <= 60) return 'admin_review';
  return 'rejected';
}

export interface ModerationProvider {
  moderate(target: ModerationTarget): Promise<ModerationProviderResult>;
}

export class ModerationProviderError extends Error {
  readonly retryable: boolean;
  readonly cause?: unknown;

  constructor(message: string, options: { retryable?: boolean; cause?: unknown } = {}) {
    super(message);
    this.name = 'ModerationProviderError';
    this.retryable = options.retryable ?? true;
    this.cause = options.cause;
  }
}

export class GeminiInputSafetyError extends ModerationProviderError {
  readonly ratings: unknown;

  constructor(ratings: unknown = undefined) {
    super('Gemini blocked the moderation input for safety reasons', {
      retryable: false,
    });
    this.name = 'GeminiInputSafetyError';
    this.ratings = ratings;
  }
}
