import assert from 'node:assert/strict';
import test from 'node:test';
import {
  GeminiInputSafetyError,
  ModerationProviderError,
  type ModerationTarget,
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

const commentTarget: ModerationTarget = {
  targetType: 'comment',
  content: 'Helpful study advice.',
  tags: [],
  images: [],
};

function createGateway(
  createInteraction: (request: GeminiInteractionRequest) => Promise<{ output_text?: string }>,
) {
  return new GeminiModerationGateway({
    apiKey: 'test-key',
    primaryModel: 'gemini-3.5-flash-lite',
    fallbackModel: 'gemini-3.8-flash',
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

  assert.equal(request?.model, 'gemini-3.5-flash-lite');
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
  assert.equal(result.model, 'gemini-3.5-flash-lite');
  assert.equal(result.providerAttempts, 1);
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
  let calls = 0;
  const gateway = createGateway(async () => {
    calls += 1;
    return { output_text: '{not-json' };
  });

  await assert.rejects(
    gateway.moderate({ targetType: 'comment', content: 'hello', tags: [], images: [] }),
    (error: unknown) => error instanceof ModerationProviderError && error.retryable === false,
  );
  assert.equal(calls, 1);
});

test('preserves explicit Gemini input safety blocks for fail-closed handling', async () => {
  let calls = 0;
  const gateway = createGateway(async () => {
    calls += 1;
    throw new GeminiInputSafetyError([{ category: 'HARM_CATEGORY_HATE_SPEECH' }]);
  });

  await assert.rejects(
    gateway.moderate({ targetType: 'post', content: 'blocked', tags: [], images: [] }),
    (error: unknown) =>
      error instanceof GeminiInputSafetyError &&
      error.retryable === false &&
      Array.isArray(error.ratings),
  );
  assert.equal(calls, 1);
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
  let calls = 0;
  const gateway = createGateway(async () => {
    calls += 1;
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
  assert.equal(calls, 1);
});

test('falls back to 3.8 Flash once after primary 429', async () => {
  const requests: GeminiInteractionRequest[] = [];
  const gateway = createGateway(async (request) => {
    requests.push(request);
    if (requests.length === 1) throw { status: 429, message: 'quota' };
    return { output_text: JSON.stringify(safeResponse) };
  });

  const result = await gateway.moderate(commentTarget);

  assert.deepEqual(requests.map((request) => request.model), [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
  ]);
  assert.equal(result.model, 'gemini-3.8-flash');
  assert.equal(result.providerAttempts, 2);
});

test('falls back to 3.8 Flash once after primary 503', async () => {
  const models: string[] = [];
  const gateway = createGateway(async (request) => {
    models.push(request.model);
    if (models.length === 1) throw { status: 503, message: 'unavailable' };
    return { output_text: JSON.stringify(safeResponse) };
  });

  await gateway.moderate(commentTarget);
  assert.deepEqual(models, ['gemini-3.5-flash-lite', 'gemini-3.8-flash']);
});

test('retries the primary once for a timeout instead of using fallback', async () => {
  const models: string[] = [];
  const gateway = createGateway(async (request) => {
    models.push(request.model);
    if (models.length === 1) throw new Error('request timed out');
    return { output_text: JSON.stringify(safeResponse) };
  });

  await gateway.moderate(commentTarget);
  assert.deepEqual(models, ['gemini-3.5-flash-lite', 'gemini-3.5-flash-lite']);
});

test('never makes a third provider call', async () => {
  let calls = 0;
  const gateway = createGateway(async () => {
    calls += 1;
    throw { status: 503, message: 'unavailable' };
  });

  await assert.rejects(gateway.moderate(commentTarget));
  assert.equal(calls, 2);
});
