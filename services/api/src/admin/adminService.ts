import type {
  AdminRepository,
  AdminService,
  OverviewView,
} from './adminTypes.js';

export function createAdminService(
  repository: AdminRepository,
  reportReviewThreshold: number,
): AdminService {
  return {
    getOverview: async (): Promise<OverviewView> => {
      const snapshot = await repository.getOverviewSnapshot();
      const reportCases = new Map<
        string,
        {
          reporters: Set<string>;
          statuses: Set<string>;
        }
      >();

      for (const row of snapshot.reportRows) {
        if (row.targetType !== 'post' && row.targetType !== 'comment') {
          continue;
        }

        const key = `${row.targetType}:${row.targetId}`;
        const reportCase = reportCases.get(key) ?? {
          reporters: new Set<string>(),
          statuses: new Set<string>(),
        };

        if (row.reporterId) {
          reportCase.reporters.add(row.reporterId);
        }
        reportCase.statuses.add(row.status);
        reportCases.set(key, reportCase);
      }

      const pendingReportCases = [...reportCases.values()].filter(
        (reportCase) =>
          reportCase.statuses.has('open') &&
          !reportCase.statuses.has('reviewing') &&
          reportCase.reporters.size >= reportReviewThreshold,
      ).length;

      return {
        pendingCreatorRequests: snapshot.pendingCreatorRequests,
        pendingReportCases,
        pendingAppeals: snapshot.pendingAppeals,
        recentDecisions: snapshot.recentAuditRows.map((row) => ({ ...row })),
      };
    },
  };
}
