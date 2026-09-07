import assert from 'node:assert/strict';
import test from 'node:test';
import {
  GeminiInputSafetyError,
  ModerationProviderError,
} from './moderationTypes.js';
import {
  GeminiModerationGateway,
  type GeminiInteractionRequest,
} from './geminiModerationGateway.js';

const safeResponse = {
  overallRiskScore: 12,
  categoryScores: {
    harassmentBullying: 1,
    hate: 0,
    sexual: 0,
    violenceDanger: 2,
    selfHarm: 0,
    spamScam: 4,
    privacyExposure: 1,
  },
  evidence: ['No harmful signal found'],
  userReason: 'This content appears safe for the CyanZone community.',
  evidenceSource: 'text',
};

function createGateway(
  createInteraction: (request: GeminiInteractionRequest) => Promise<{ output_text?: string }>,
) {
  return new GeminiModerationGateway({
    apiKey: 'test-key',
    model: 'gemini-3.8-flash',
    timeoutMs: 8500,
    createInteraction,
  });
}

test('sends text and every trusted image URI to Gemini and parses structured output', async () => {
  let request: GeminiInteractionRequest | undefined;
  const gateway = createGateway(async (input) => {
    request = input;
    return { output_text: JSON.stringify(safeResponse) };
  });

  const result = await gateway.moderate({
    targetType: 'post',
    title: 'Weekend project',
    content: 'I finished my science project today.',
    tags: ['school', 'project'],
    images: [
      { uri: 'https://example.supabase.co/storage/v1/object/public/posts/a.webp', mimeType: 'image/webp' },
      { uri: 'https://example.supabase.co/storage/v1/object/public/posts/b.jpg', mimeType: 'image/jpeg' },
    ],
  });

  assert.equal(request?.model, 'gemini-3.8-flash');
  assert.equal(request?.generation_config.thinking_level, 'low');
  assert.equal(request?.response_format?.mime_type, 'application/json');
  assert.equal(request?.input.filter((part) => part.type === 'image').length, 2);
  assert.deepEqual(
    request?.input.filter((part) => part.type === 'image').map((part) => part.uri),
    [
      'https://example.supabase.co/storage/v1/object/public/posts/a.webp',
      'https://example.supabase.co/storage/v1/object/public/posts/b.jpg',
    ],
  );
  assert.equal(result.model, 'gemini-3.8-flash');
  assert.equal(result.promptVersion, 'cyanzone-moderation-v1');
  assert.equal(result.overallRiskScore, 12);
});

test('sends comment text without image parts', async () => {
  let request: GeminiInteractionRequest | undefined;
  const gateway = createGateway(async (input) => {
    request = input;
    return { output_text: JSON.stringify(safeResponse) };
  });

  await gateway.moderate({
    targetType: 'comment',
    content: 'Nice work!',
    tags: [],
    images: [],
  });

  assert.equal(request?.input.filter((part) => part.type === 'image').length, 0);
  assert.equal(request?.input.filter((part) => part.type === 'text').length, 1);
});

test('rejects malformed structured output as a non-retryable provider error', async () => {
  const gateway = createGateway(async () => ({ output_text: '{not-json' }));

  await assert.rejects(
    gateway.moderate({ targetType: 'comment', content: 'hello', tags: [], images: [] }),
    (error: unknown) => error instanceof ModerationProviderError && error.retryable === false,
  );
});

test('preserves explicit Gemini input safety blocks for fail-closed handling', async () => {
  const gateway = createGateway(async () => {
    throw new GeminiInputSafetyError([{ category: 'HARM_CATEGORY_HATE_SPEECH' }]);
  });

  await assert.rejects(
    gateway.moderate({ targetType: 'post', content: 'blocked', tags: [], images: [] }),
    (error: unknown) =>
      error instanceof GeminiInputSafetyError &&
      error.retryable === false &&
      Array.isArray(error.ratings),
  );
});

test('treats a generic 400 request error as permanent provider failure, not a safety block', async () => {
  const gateway = createGateway(async () => {
    throw { status: 400, message: 'Invalid response schema field.' };
  });

  await assert.rejects(
    gateway.moderate({ targetType: 'comment', content: 'hello', tags: [], images: [] }),
    (error: unknown) =>
      error instanceof ModerationProviderError &&
      !(error instanceof GeminiInputSafetyError) &&
      error.retryable === false,
  );
});

test('recognizes explicit blocked safety metadata without relying on message text', async () => {
  const gateway = createGateway(async () => {
    throw {
      status: 400,
      blockReason: 'SAFETY',
      safetyRatings: [
        {
          category: 'HARM_CATEGORY_HATE_SPEECH',
          probability: 'HIGH',
          blocked: true,
        },
      ],
      evidenceSource: 'image',
    };
  });

  await assert.rejects(
    gateway.moderate({ targetType: 'post', content: 'blocked', tags: [], images: [] }),
    (error: unknown) =>
      error instanceof GeminiInputSafetyError &&
      error.evidenceSource === 'image' &&
      Array.isArray(error.ratings),
  );
});
