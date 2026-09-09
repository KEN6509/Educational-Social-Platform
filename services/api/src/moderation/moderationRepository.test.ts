import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createModerationRepository,
  type ModerationSupabaseClient,
} from './moderationRepository.js';

function query(data: unknown, error: { message: string } | null = null) {
  const chain = {
    select: () => chain,
    eq: () => chain,
    order: async () => ({ data, error }),
    maybeSingle: async () => ({ data, error }),
  };
  return chain;
}

function createClient(options: {
  tables?: Record<string, unknown>;
  rpcRows?: Record<string, unknown>;
  rpcCalls?: Array<{ name: string; args: Record<string, unknown> }>;
}) {
  const rpcCalls = options.rpcCalls ?? [];
  const client = {
    from: (table: string) => query(options.tables?.[table] ?? null),
    rpc: async (name: string, args: Record<string, unknown>) => {
      rpcCalls.push({ name, args });
      return { data: options.rpcRows?.[name] ?? null, error: null };
    },
    storage: {
      from: (_bucket: string) => ({
        getPublicUrl: (path: string) => ({
          data: {
            publicUrl: `https://project.supabase.co/storage/v1/object/public/images/${path}`,
          },
        }),
      }),
    },
  } as unknown as ModerationSupabaseClient;
  return { client, rpcCalls };
}

const postRow = {
  id: 'post-1',
  author_id: 'member-1',
  title: 'A post',
  content: 'Hello from a post',
  tags: ['school'],
  moderation_revision: 3,
};

test('loads a post and reconstructs ordered image URLs from storage paths', async () => {
  const { client } = createClient({
    tables: {
      posts: postRow,
      post_images: [
        { storage_path: 'member-1/post-1/a.jpg', mime_type: null, position: 1 },
      ],
    },
  });
  const repository = createModerationRepository(client);

  const target = await repository.loadTarget('post', 'post-1');

  assert.deepEqual(target, {
    id: 'post-1',
    ownerId: 'member-1',
    revision: 3,
    target: {
      targetType: 'post',
      title: 'A post',
      content: 'Hello from a post',
      tags: ['school'],
      images: [
        {
          uri: 'https://project.supabase.co/storage/v1/object/public/images/member-1/post-1/a.jpg',
          mimeType: 'image/jpeg',
        },
      ],
    },
  });
});

test('loads comment text without attempting image storage reads', async () => {
  const { client } = createClient({
    tables: {
      comments: {
        id: 'comment-1',
        author_id: 'member-1',
        content: 'Nice work',
        moderation_revision: 1,
      },
    },
  });
  const repository = createModerationRepository(client);

  const target = await repository.loadTarget('comment', 'comment-1');

  assert.equal(target?.target.images.length, 0);
  assert.equal(target?.target.content, 'Nice work');
});

test('calls moderation RPCs with exact revision, owner, and claim arguments', async () => {
  const rpcRows = {
    prepare_content_moderation: {
      id: 'case-1',
      target_type: 'post',
      target_id: 'post-1',
      owner_id: 'member-1',
      moderation_revision: 3,
      state: 'processing',
      claim_token: 'claim-1',
      attempt_count: 1,
    },
    apply_ai_moderation_result: {
      id: 'case-1',
      target_type: 'post',
      target_id: 'post-1',
      owner_id: 'member-1',
      moderation_revision: 3,
      state: 'approved',
      claim_token: 'claim-1',
      attempt_count: 1,
    },
    mark_content_moderation_failed: {
      id: 'case-1',
      target_type: 'post',
      target_id: 'post-1',
      owner_id: 'member-1',
      moderation_revision: 3,
      state: 'failed',
      claim_token: 'claim-1',
      attempt_count: 1,
    },
  };
  const { client, rpcCalls } = createClient({ rpcRows });
  const repository = createModerationRepository(client);

  await repository.prepare('post', 'post-1', 'member-1');
  await repository.applyResult('case-1', 3, {
    claimToken: 'claim-1',
    state: 'approved',
    recommendedDecision: 'approved',
    overallRiskScore: 10,
    categoryScores: {
      harassmentBullying: 0,
      hate: 0,
      sexual: 0,
      violenceDanger: 0,
      selfHarm: 0,
      spamScam: 0,
      privacyExposure: 0,
    },
    evidence: ['safe'],
    userReason: 'safe',
    evidenceSource: 'text',
    model: 'gemini-3.8-flash',
    promptVersion: 'cyanzone-moderation-v2',
    attemptCount: 1,
  });
  await repository.markFailed('case-1', 3, {
    claimToken: 'claim-1',
    code: 'provider_timeout',
    message: 'timed out',
    attemptCount: 1,
  });

  assert.deepEqual(
    rpcCalls.map((call) => call.name),
    [
      'prepare_content_moderation',
      'apply_ai_moderation_result',
      'mark_content_moderation_failed',
    ],
  );
  assert.equal(rpcCalls[0].args.p_owner_id, 'member-1');
  assert.equal(rpcCalls[1].args.p_expected_revision, 3);
  assert.equal(rpcCalls[2].args.p_claim_token, 'claim-1');
});

test('rejects unsupported image extensions before provider invocation', async () => {
  const { client } = createClient({
    tables: {
      posts: postRow,
      post_images: [
        { storage_path: 'member-1/post-1/file.exe', mime_type: null, position: 1 },
      ],
    },
  });
  const repository = createModerationRepository(client);

  await assert.rejects(
    repository.loadTarget('post', 'post-1'),
    /Unsupported moderation image type/,
  );
});
