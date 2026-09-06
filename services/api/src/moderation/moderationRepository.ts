import type {
  ModerationCase,
  ModerationRepository,
  ModerationTargetRecord,
  ModerationTargetType,
  PersistedModerationFailure,
  PersistedModerationResult,
  SupportedImageMimeType,
} from './moderationTypes.js';

export type ModerationSupabaseClient = {
  from: (table: string) => any;
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { message: string } | null }>;
  storage: {
    from: (bucket: string) => {
      getPublicUrl: (path: string) => { data: { publicUrl: string } };
    };
  };
};

const mimeByExtension: Record<string, SupportedImageMimeType> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
};

export function createModerationRepository(
  client: ModerationSupabaseClient,
): ModerationRepository {
  return {
    async loadTarget(type, id) {
      if (type === 'post') {
        const postResult = await client
          .from('posts')
          .select('id, author_id, title, content, tags, moderation_revision')
          .eq('id', id)
          .maybeSingle();
        assertQuerySucceeded(postResult.error, 'Unable to read post.');
        if (!postResult.data) return null;

        const imageResult = await client
          .from('post_images')
          .select('storage_path, mime_type, position')
          .eq('post_id', id)
          .order('position', { ascending: true });
        assertQuerySucceeded(imageResult.error, 'Unable to read post images.');

        return {
          id: String(postResult.data.id),
          ownerId: String(postResult.data.author_id),
          revision: Number(postResult.data.moderation_revision),
          target: {
            targetType: 'post',
            title: typeof postResult.data.title === 'string' ? postResult.data.title : null,
            content: String(postResult.data.content ?? ''),
            tags: toStringArray(postResult.data.tags),
            images: (imageResult.data ?? []).map((row: Record<string, unknown>) =>
              mapImage(client, row),
            ),
          },
        };
      }

      const commentResult = await client
        .from('comments')
        .select('id, author_id, content, moderation_revision')
        .eq('id', id)
        .maybeSingle();
      assertQuerySucceeded(commentResult.error, 'Unable to read comment.');
      if (!commentResult.data) return null;

      return {
        id: String(commentResult.data.id),
        ownerId: String(commentResult.data.author_id),
        revision: Number(commentResult.data.moderation_revision),
        target: {
          targetType: 'comment',
          title: null,
          content: String(commentResult.data.content ?? ''),
          tags: [],
          images: [],
        },
      };
    },

    async prepare(type, id, ownerId) {
      const result = await client.rpc('prepare_content_moderation', {
        p_target_type: type,
        p_target_id: id,
        p_owner_id: ownerId,
      });
      return mapRpcCase(result, 'Unable to prepare moderation.');
    },

    async applyResult(caseId, revision, result) {
      const rpcResult = await client.rpc('apply_ai_moderation_result', {
        p_case_id: caseId,
        p_expected_revision: revision,
        p_claim_token: result.claimToken,
        p_case_state: result.state,
        p_overall_risk_score: result.overallRiskScore,
        p_category_scores: result.categoryScores,
        p_evidence: result.evidence,
        p_user_reason: result.userReason,
        p_model: result.model,
        p_prompt_version: result.promptVersion,
        p_attempt_count: result.attemptCount,
      });
      return mapRpcCase(rpcResult, 'Unable to apply moderation result.');
    },

    async markFailed(caseId, revision, failure) {
      const rpcResult = await client.rpc('mark_content_moderation_failed', {
        p_case_id: caseId,
        p_expected_revision: revision,
        p_claim_token: failure.claimToken,
        p_failure_code: failure.code,
        p_failure_message: failure.message,
        p_attempt_count: failure.attemptCount,
      });
      return mapRpcCase(rpcResult, 'Unable to save moderation failure.');
    },
  };
}

function mapImage(
  client: ModerationSupabaseClient,
  row: Record<string, unknown>,
) {
  const storagePath = typeof row.storage_path === 'string' ? row.storage_path : '';
  if (!storagePath) {
    throw new Error('Moderation image is missing its storage path.');
  }

  const storedMime = typeof row.mime_type === 'string' ? row.mime_type : null;
  const extension = storagePath.slice(storagePath.lastIndexOf('.')).toLowerCase();
  const mimeType = storedMime || mimeByExtension[extension];
  if (!mimeType || !(Object.values(mimeByExtension) as string[]).includes(mimeType)) {
    throw new Error(`Unsupported moderation image type: ${extension || 'unknown'}`);
  }

  return {
    uri: client.storage.from('images').getPublicUrl(storagePath).data.publicUrl,
    mimeType: mimeType as SupportedImageMimeType,
  };
}

function mapRpcCase(result: { data: unknown; error: { message: string } | null }, fallback: string): ModerationCase {
  assertQuerySucceeded(result.error, fallback);
  if (!result.data || Array.isArray(result.data)) {
    throw new Error(fallback);
  }

  const row = result.data as Record<string, unknown>;
  return {
    id: String(row.id),
    targetType: row.target_type as ModerationTargetType,
    targetId: String(row.target_id),
    ownerId: String(row.owner_id),
    revision: Number(row.moderation_revision),
    state: row.state as ModerationCase['state'],
    claimToken: typeof row.claim_token === 'string' ? row.claim_token : null,
    attemptCount: Number(row.attempt_count ?? 0),
  };
}

function toStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

function assertQuerySucceeded(
  error: { message: string } | null,
  message: string,
): asserts error is null {
  if (error) throw new Error(`${message} ${error.message}`);
}
