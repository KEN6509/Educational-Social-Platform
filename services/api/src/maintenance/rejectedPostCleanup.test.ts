import assert from 'node:assert/strict';
import test from 'node:test';

import { createRejectedPostCleanup, type RejectedPostCleanupRepository } from './rejectedPostCleanup.js';

test('removes storage before finalizing a ready rejected post', async () => {
  const calls: string[] = [];
  const repository: RejectedPostCleanupRepository = {
    listExpiredCaseIds: async () => ['case-1'],
    prepare: async () => ({ action: 'ready', storagePaths: ['user/post/a.jpg'] }),
    removeStorageObjects: async () => { calls.push('storage'); },
    finalize: async () => { calls.push('database'); return 'deleted'; },
  };
  const result = await createRejectedPostCleanup(repository).run();
  assert.deepEqual(calls, ['storage', 'database']);
  assert.deepEqual(result, { processed: 1, deleted: 1, skipped: 0, failed: 0 });
});

test('does not finalize when Storage deletion fails', async () => {
  let finalized = false;
  const repository: RejectedPostCleanupRepository = {
    listExpiredCaseIds: async () => ['case-1'],
    prepare: async () => ({ action: 'ready', storagePaths: ['user/post/a.jpg'] }),
    removeStorageObjects: async () => { throw new Error('storage failure'); },
    finalize: async () => { finalized = true; return 'deleted'; },
  };
  const result = await createRejectedPostCleanup(repository).run();
  assert.equal(finalized, false);
  assert.equal(result.failed, 1);
});
