import { GoogleGenAI } from '@google/genai';
import {
  GEMINI_MODERATION_RESPONSE_SCHEMA,
  parseModerationResult,
} from './moderationSchemas.js';
import {
  GeminiInputSafetyError,
  MODERATION_PROMPT_VERSION,
  ModerationProviderError,
  type ModerationProvider,
  type ModerationTarget,
  type ModerationProviderResult,
} from './moderationTypes.js';

export type GeminiTextInputPart = {
  type: 'text';
  text: string;
};

export type GeminiImageInputPart = {
  type: 'image';
  uri: string;
  mime_type: ModerationTarget['images'][number]['mimeType'];
};

export type GeminiInteractionInputPart = GeminiTextInputPart | GeminiImageInputPart;

export type GeminiInteractionRequest = {
  model: string;
  input: GeminiInteractionInputPart[];
  system_instruction: string;
  generation_config: {
    thinking_level: 'low';
    max_output_tokens: number;
  };
  response_format: {
    type: 'text';
    mime_type: 'application/json';
    schema: unknown;
  };
};

export type GeminiInteractionResponse = {
  output_text?: string;
  outputText?: string;
  text?: string;
  safety_blocked?: boolean;
  safety_ratings?: unknown;
  evidence_source?: 'text' | 'image' | 'both';
};

export type GeminiInteractionRequestOptions = {
  timeout: number;
  maxRetries: 0;
};

export type GeminiInteractionClient = {
  create(
    request: GeminiInteractionRequest,
    options: GeminiInteractionRequestOptions,
  ): Promise<GeminiInteractionResponse>;
};

export type GeminiModerationGatewayOptions = {
  apiKey: string;
  primaryModel: string;
  fallbackModel: string;
  timeoutMs: number;
  createInteraction?: GeminiInteractionClient['create'];
};

const SYSTEM_INSTRUCTION = [
  'You are CyanZone content moderation, not a chat assistant.',
  'Review the supplied post or comment text and optional images for a youth-focused social app.',
  'Use the exact JSON schema. Do not include markdown or extra keys.',
  'Score each category from 0 (no concern) to 100 (severe concern).',
  'Overall risk should reflect the highest credible concern, not a simple average.',
  'Only cite short, concrete evidence from the supplied text or image. Do not invent context.',
  'If the content is ambiguous, choose a lower score and explain the uncertainty briefly.',
].join(' ');

export class GeminiModerationGateway implements ModerationProvider {
  private readonly primaryModel: string;
  private readonly fallbackModel: string;
  private readonly timeoutMs: number;
  private readonly createInteraction: GeminiInteractionClient['create'];

  constructor(options: GeminiModerationGatewayOptions) {
    this.primaryModel = options.primaryModel;
    this.fallbackModel = options.fallbackModel;
    this.timeoutMs = options.timeoutMs;
    this.createInteraction =
      options.createInteraction ??
      createGoogleInteraction({ apiKey: options.apiKey });
  }

  async moderate(target: ModerationTarget): Promise<ModerationProviderResult> {
    try {
      return await this.moderateWithModel(target, this.primaryModel, 1);
    } catch (error) {
      const primaryError = withProviderAttempts(normalizeGeminiError(error), 1);
      if (!primaryError.retryable) throw primaryError;

      const secondModel = primaryError.statusCode === 429 ||
          primaryError.statusCode === 503
        ? this.fallbackModel
        : this.primaryModel;

      try {
        return await this.moderateWithModel(target, secondModel, 2);
      } catch (secondError) {
        throw withProviderAttempts(normalizeGeminiError(secondError), 2);
      }
    }
  }

  private async moderateWithModel(
    target: ModerationTarget,
    model: string,
    providerAttempts: number,
  ): Promise<ModerationProviderResult> {
    const request: GeminiInteractionRequest = {
      model,
      system_instruction: SYSTEM_INSTRUCTION,
      generation_config: {
        thinking_level: 'low',
        max_output_tokens: 700,
      },
      response_format: {
        type: 'text',
        mime_type: 'application/json',
        schema: GEMINI_MODERATION_RESPONSE_SCHEMA,
      },
      input: [
        {
          type: 'text',
          text: buildModerationPrompt(target),
        },
        ...target.images.map((image): GeminiImageInputPart => ({
          type: 'image',
          uri: image.uri,
          mime_type: image.mimeType,
        })),
      ],
    };

    let response: GeminiInteractionResponse;
    try {
      response = await this.createInteraction(request, {
        timeout: this.timeoutMs,
        maxRetries: 0,
      });
    } catch (error) {
      throw error;
    }

    if (response.safety_blocked) {
      throw new GeminiInputSafetyError(
        response.safety_ratings,
        response.evidence_source,
      );
    }

    const output = response.output_text ?? response.outputText ?? response.text;
    if (!output) {
      throw new ModerationProviderError('Gemini returned no moderation output', {
        retryable: false,
      });
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(output);
    } catch (error) {
      throw new ModerationProviderError('Gemini returned malformed JSON moderation output', {
        retryable: false,
        cause: error,
      });
    }

    try {
      return {
        ...parseModerationResult(parsed, model, MODERATION_PROMPT_VERSION),
        providerAttempts,
      };
    } catch (error) {
      throw new ModerationProviderError('Gemini returned schema-invalid moderation output', {
        retryable: false,
        cause: error,
      });
    }
  }
}

function createGoogleInteraction(options: {
  apiKey: string;
}): GeminiInteractionClient['create'] {
  const client = new GoogleGenAI({ apiKey: options.apiKey }) as unknown as {
    interactions: GeminiInteractionClient;
  };

  return client.interactions.create.bind(client.interactions);
}

function buildModerationPrompt(target: ModerationTarget): string {
  const title = target.title?.trim() || '(none)';
  const tags = target.tags.length > 0 ? target.tags.join(', ') : '(none)';
  return [
    `Target type: ${target.targetType}`,
    `Title: ${title}`,
    `Tags: ${tags}`,
    'Content:',
    target.content,
    '',
    `There are ${target.images.length} attached image(s). Inspect them only when present.`,
    'Return the seven category scores, a concise evidence list, a user-safe reason, and whether the evidence came from text, image, or both.',
  ].join('\n');
}

function normalizeGeminiError(error: unknown): ModerationProviderError {
  if (error instanceof ModerationProviderError) return error;

  const safety = findExplicitSafetySignal(error);
  if (safety) {
    return new GeminiInputSafetyError(safety.ratings, safety.evidenceSource);
  }

  return new ModerationProviderError('Gemini moderation request failed', {
    retryable: isRetryableProviderError(error),
    cause: error,
    statusCode: findHttpStatus(error) ?? undefined,
  });
}

function withProviderAttempts(
  error: ModerationProviderError,
  providerAttempts: number,
): ModerationProviderError {
  if (error instanceof GeminiInputSafetyError) {
    return new GeminiInputSafetyError(
      error.ratings,
      error.evidenceSource,
      providerAttempts,
    );
  }
  return new ModerationProviderError(error.message, {
    retryable: error.retryable,
    cause: error.cause,
    statusCode: error.statusCode,
    providerAttempts,
  });
}

type UnknownRecord = Record<string, unknown>;

function findExplicitSafetySignal(
  value: unknown,
  depth = 0,
): { ratings: unknown; evidenceSource?: 'text' | 'image' | 'both' } | null {
  if (depth > 3 || value == null || typeof value !== 'object') return null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const nested = findExplicitSafetySignal(item, depth + 1);
      if (nested) return nested;
    }
    return null;
  }

  const record = value as UnknownRecord;
  const ratings = record.safetyRatings ?? record.safety_ratings;
  const reason = record.blockReason ?? record.blockedReason ?? record.block_reason;
  const normalizedReason = typeof reason === 'string' ? reason.toUpperCase() : '';
  const explicitReason = [
    'SAFETY',
    'IMAGE_SAFETY',
    'PROHIBITED_CONTENT',
    'BLOCKLIST',
  ].includes(normalizedReason);
  const blockedRating = Array.isArray(ratings) && ratings.some((rating) => {
    return rating != null &&
      typeof rating === 'object' &&
      (rating as UnknownRecord).blocked === true;
  });

  if (explicitReason || blockedRating || record.safety_blocked === true) {
    return {
      ratings,
      evidenceSource: parseEvidenceSource(
        record.evidenceSource ?? record.evidence_source,
      ),
    };
  }

  for (const key of ['error', 'details', 'response', 'cause']) {
    const nested = findExplicitSafetySignal(record[key], depth + 1);
    if (nested) return nested;
  }
  return null;
}

function parseEvidenceSource(
  value: unknown,
): 'text' | 'image' | 'both' | undefined {
  return value === 'text' || value === 'image' || value === 'both'
    ? value
    : undefined;
}

function isRetryableProviderError(error: unknown): boolean {
  const status = findHttpStatus(error);
  if (status == null) return true;
  if (status === 408 || status === 409 || status === 429) return true;
  return status >= 500;
}

function findHttpStatus(value: unknown, depth = 0): number | null {
  if (depth > 2 || value == null || typeof value !== 'object') return null;
  const record = value as UnknownRecord;
  const status = record.status ?? record.statusCode;
  if (typeof status === 'number' && Number.isInteger(status)) return status;
  for (const key of ['error', 'response', 'cause']) {
    const nested = findHttpStatus(record[key], depth + 1);
    if (nested != null) return nested;
  }
  return null;
}
