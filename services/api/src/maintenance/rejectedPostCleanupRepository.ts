import type { CleanupPreparation, RejectedPostCleanupRepository } from './rejectedPostCleanup.js';

export type RejectedPostCleanupClient = {
  from: (table: string) => any;
  rpc: (name: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }>;
  storage: { from: (bucket: string) => { remove: (paths: string[]) => Promise<{ error: { message: string } | null }> } };
};

function assertSuccess(error: { message: string } | null, fallback: string): asserts error is null {
  if (error) throw new Error(fallback);
}

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function mapPreparation(value: unknown): CleanupPreparation {
  const row = objectValue(Array.isArray(value) ? value[0] : value);
  const action = row.action;
  return {
    action: action === 'ready' || action === 'missing' || action === 'superseded'
      ? action
      : 'skip',
    storagePaths: Array.isArray(row.storage_paths)
      ? row.storage_paths.filter((path): path is string => typeof path === 'string' && path.length > 0)
      : [],
  };
}

function mapFinalize(value: unknown): 'deleted' | 'missing' | 'skip' {
  const action = objectValue(Array.isArray(value) ? value[0] : value).action;
  return action === 'deleted' || action === 'missing' ? action : 'skip';
}

export function createRejectedPostCleanupRepository(client: RejectedPostCleanupClient): RejectedPostCleanupRepository {
  return {
    async listExpiredCaseIds(batchSize) {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      const result = await client
        .from('content_moderation_cases')
        .select('id')
        .eq('target_type', 'post')
        .eq('state', 'rejected')
        .eq('decision_source', 'admin')
        .lte('completed_at', cutoff)
        .order('completed_at', { ascending: true })
        .limit(batchSize);
      assertSuccess(result.error, 'Unable to list rejected-post cleanup cases.');
      return (result.data ?? []).map((row: Record<string, unknown>) => String(row.id));
    },
    async prepare(caseId) {
      const result = await client.rpc('prepare_expired_rejected_post_cleanup', { p_case_id: caseId });
      assertSuccess(result.error, 'Unable to prepare rejected-post cleanup.');
      return mapPreparation(result.data);
    },
    async removeStorageObjects(paths) {
      const result = await client.storage.from('images').remove(paths);
      assertSuccess(result.error, 'Unable to remove rejected-post media.');
    },
    async finalize(caseId) {
      const result = await client.rpc('finalize_expired_rejected_post_cleanup', { p_case_id: caseId });
      assertSuccess(result.error, 'Unable to finalize rejected-post cleanup.');
      return mapFinalize(result.data);
    },
  };
}
