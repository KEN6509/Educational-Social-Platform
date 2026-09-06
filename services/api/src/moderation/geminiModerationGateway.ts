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
    thinking_level: 'minimal';
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
};

export type GeminiInteractionClient = {
  create(request: GeminiInteractionRequest): Promise<GeminiInteractionResponse>;
};

export type GeminiModerationGatewayOptions = {
  apiKey: string;
  model: string;
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
  private readonly model: string;
  private readonly createInteraction: GeminiInteractionClient['create'];

  constructor(options: GeminiModerationGatewayOptions) {
    this.model = options.model;
    this.createInteraction =
      options.createInteraction ??
      createGoogleInteraction({
        apiKey: options.apiKey,
        timeoutMs: options.timeoutMs,
      });
  }

  async moderate(target: ModerationTarget): Promise<ModerationProviderResult> {
    const request: GeminiInteractionRequest = {
      model: this.model,
      system_instruction: SYSTEM_INSTRUCTION,
      generation_config: {
        thinking_level: 'minimal',
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
      response = await this.createInteraction(request);
    } catch (error) {
      throw normalizeGeminiError(error);
    }

    if (response.safety_blocked) {
      throw new GeminiInputSafetyError(response.safety_ratings);
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
      return parseModerationResult(parsed, this.model, MODERATION_PROMPT_VERSION);
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
  timeoutMs: number;
}): GeminiInteractionClient['create'] {
  const client = new GoogleGenAI({
    apiKey: options.apiKey,
    httpOptions: {
      timeout: options.timeoutMs,
      retryOptions: { attempts: 1 },
    },
  }) as unknown as { interactions: GeminiInteractionClient };

  return (request) => client.interactions.create(request);
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

  const details = error as {
    message?: unknown;
    status?: unknown;
    safetyRatings?: unknown;
    safety_ratings?: unknown;
  };
  const message = typeof details?.message === 'string' ? details.message : String(error);
  if (
    /safety|blocked|harm[_ -]?category|recitation/i.test(message) ||
    details?.status === 400
  ) {
    return new GeminiInputSafetyError(details.safetyRatings ?? details.safety_ratings);
  }

  return new ModerationProviderError('Gemini moderation request failed', {
    retryable: true,
    cause: error,
  });
}
