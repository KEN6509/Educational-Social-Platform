export type CleanupPreparation = {
  action: 'ready' | 'missing' | 'superseded' | 'skip';
  storagePaths: string[];
};

export type RejectedPostCleanupRepository = {
  listExpiredCaseIds(batchSize: number): Promise<string[]>;
  prepare(caseId: string): Promise<CleanupPreparation>;
  removeStorageObjects(paths: string[]): Promise<void>;
  finalize(caseId: string): Promise<'deleted' | 'missing' | 'skip'>;
};

export type CleanupResult = {
  processed: number;
  deleted: number;
  skipped: number;
  failed: number;
};

export function createRejectedPostCleanup(repository: RejectedPostCleanupRepository) {
  return {
    async run(batchSize = 100): Promise<CleanupResult> {
      const caseIds = await repository.listExpiredCaseIds(batchSize);
      const result: CleanupResult = { processed: 0, deleted: 0, skipped: 0, failed: 0 };

      for (const caseId of caseIds) {
        result.processed += 1;
        try {
          const prepared = await repository.prepare(caseId);
          if (prepared.action !== 'ready') {
            result.skipped += 1;
            continue;
          }
          if (prepared.storagePaths.length > 0) {
            await repository.removeStorageObjects(prepared.storagePaths);
          }
          const finalized = await repository.finalize(caseId);
          if (finalized === 'deleted') result.deleted += 1;
          else result.skipped += 1;
        } catch {
          // Keep the case eligible for the next bounded run when Storage or RPC fails.
          result.failed += 1;
        }
      }

      return result;
    },
  };
}
