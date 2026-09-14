import assert from 'node:assert/strict';
import test from 'node:test';

import { createRejectedPostCleanupRepository } from './rejectedPostCleanupRepository.js';

test('adapter applies bounded admin-only filters and calls the safe RPCs', async () => {
  const filters: Array<[string, unknown]> = [];
  const rpcCalls: Array<[string, Record<string, unknown>]> = [];
  let removed: string[] = [];
  const query = {
    select() { return this; },
    eq(column: string, value: unknown) { filters.push([column, value]); return this; },
    lte() { return this; }, order() { return this; }, limit() { return Promise.resolve({ data: [{ id: 'case-1' }], error: null }); },
  };
  const client = {
    from() { return query; },
    rpc(name: string, args: Record<string, unknown>) {
      rpcCalls.push([name, args]);
      return Promise.resolve({ data: name.startsWith('prepare') ? { action: 'ready', storage_paths: ['user/post/a.jpg'] } : { action: 'deleted' }, error: null });
    },
    storage: { from() { return { remove(paths: string[]) { removed = paths; return Promise.resolve({ error: null }); } }; } },
  };
  const repository = createRejectedPostCleanupRepository(client);
  assert.deepEqual(await repository.listExpiredCaseIds(100), ['case-1']);
  assert.deepEqual(filters, [['target_type', 'post'], ['state', 'rejected'], ['decision_source', 'admin']]);
  assert.deepEqual(await repository.prepare('case-1'), { action: 'ready', storagePaths: ['user/post/a.jpg'] });
  await repository.removeStorageObjects(['user/post/a.jpg']);
  assert.equal(await repository.finalize('case-1'), 'deleted');
  assert.deepEqual(removed, ['user/post/a.jpg']);
  assert.deepEqual(rpcCalls, [
    ['prepare_expired_rejected_post_cleanup', { p_case_id: 'case-1' }],
    ['finalize_expired_rejected_post_cleanup', { p_case_id: 'case-1' }],
  ]);
});
