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
