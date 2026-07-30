import type {
  AdminIdentity,
} from './adminAuth.js';
import type {
  AdminRepository,
  AdminService,
  CreatorRequestDecisionInput,
  CreatorRequestListQuery,
  OverviewView,
  UserAccountStatusInput,
  UserCreatorStatusInput,
  UserListQuery,
} from './adminTypes.js';
import {
  AdminNotFoundError,
  AdminValidationError,
} from './adminTypes.js';

export function createAdminService(
  repository: AdminRepository,
  reportReviewThreshold: number,
  admin: AdminIdentity | undefined = undefined,
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
    listUsers: async (query: UserListQuery) =>
      repository.listUsers({
        ...query,
        search: query.search.trim(),
      }),
    getUser: async (userId: string) => {
      const user = await repository.getUserDetail(userId);
      if (!user) {
        throw new AdminNotFoundError('User not found.');
      }
      return user;
    },
    setUserAccountStatus: async (
      userId: string,
      input: UserAccountStatusInput,
    ) => {
      if (admin?.id === userId && input.status === 'suspended') {
        throw new AdminValidationError(
          'Administrators cannot suspend their own account.',
        );
      }
      await repository.setUserAccountStatus(userId, {
        ...input,
        reason: input.reason.trim(),
      });
    },
    setUserCreatorStatus: async (
      userId: string,
      input: UserCreatorStatusInput,
    ) => {
      await repository.setUserCreatorStatus(userId, {
        ...input,
        reason: input.reason.trim(),
      });
    },
    listCreatorRequests: async (query: CreatorRequestListQuery) =>
      repository.listCreatorRequests({
        ...query,
        search: query.search.trim(),
      }),
    getCreatorRequest: async (requestId: string) => {
      const request = await repository.getCreatorRequestDetail(requestId);
      if (!request) {
        throw new AdminNotFoundError('Creator request not found.');
      }
      return request;
    },
    decideCreatorRequest: async (
      requestId: string,
      input: CreatorRequestDecisionInput,
    ) => {
      await repository.decideCreatorRequest(requestId, {
        ...input,
        reason: input.reason.trim(),
      });
    },
  };
}
