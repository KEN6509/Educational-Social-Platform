import type {
  AdminIdentity,
} from './adminAuth.js';
import type {
  AdminRepository,
  AiModerationDecisionInput,
  AiModerationListQuery,
  AdminService,
  AppealDecisionInput,
  AppealListQuery,
  CreatorRequestDecisionInput,
  CreatorRequestListQuery,
  OverviewView,
  ReportCaseDecisionInput,
  ReportCaseListQuery,
  ReportCaseSummaryView,
  ReportTargetType,
  UserAccountStatusInput,
  UserCreatorStatusInput,
  UserListQuery,
} from './adminTypes.js';
import {
  AdminNotFoundError,
  AdminValidationError,
} from './adminTypes.js';

const CREATOR_ASSIGN_AUDIT_REASON =
  'Creator status assigned by an administrator.';
const REPORT_RETAIN_AUDIT_REASON =
  'Reported content retained by an administrator.';

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
          reportCase.statuses.has('pending_review') &&
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
    listUserPosts: async (userId: string) => {
      const user = await repository.getUserDetail(userId);
      if (!user) {
        throw new AdminNotFoundError('User not found.');
      }
      return repository.listUserPublishedPosts(userId);
    },
    getPost: async (postId: string) => {
      const post = await repository.getPostDetail(postId);
      if (!post) {
        throw new AdminNotFoundError('Post not found.');
      }
      return post;
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
      const reason = input.reason.trim();
      await repository.setUserCreatorStatus(userId, {
        ...input,
        reason:
          input.isCreator && reason.length === 0
            ? CREATOR_ASSIGN_AUDIT_REASON
            : reason,
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
    listReportCases: async (query: ReportCaseListQuery) => {
      const rows = await repository.getReportCaseRows(query);
      const grouped = new Map<string, typeof rows>();

      for (const row of rows) {
        const key = `${row.targetType}:${row.targetId}`;
        const group = grouped.get(key) ?? [];
        group.push(row);
        grouped.set(key, group);
      }

      const search = query.search.trim().toLowerCase();
      const cases: ReportCaseSummaryView[] = [...grouped.values()]
        .map((group) => {
          const first = group[0]!;
          const reporters = new Set(
            group
              .map((row) => row.reporterId)
              .filter((id): id is string => Boolean(id)),
          );
          const reasons = new Map<string, number>();
          for (const row of group) {
            reasons.set(row.reason, (reasons.get(row.reason) ?? 0) + 1);
          }

          return {
            targetType: first.targetType,
            targetId: first.targetId,
            targetTitle: first.targetTitle,
            targetExcerpt: first.targetExcerpt,
            ownerName: first.ownerName,
            status: first.status,
            totalReports: group.length,
            uniqueReporters: reporters.size,
            reasonCounts: [...reasons.entries()]
              .map(([reason, count]) => ({ reason, count }))
              .sort(
                (left, right) =>
                  right.count - left.count ||
                  left.reason.localeCompare(right.reason),
              ),
            latestReportedAt: group
              .map((row) => row.createdAt)
              .sort()
              .at(-1)!,
          };
        })
        .filter((reportCase) => reportCase.uniqueReporters >= reportReviewThreshold)
        .filter((reportCase) => {
          if (!search) {
            return true;
          }
          return [
            reportCase.targetTitle,
            reportCase.targetExcerpt,
            reportCase.ownerName,
          ].some((value) => value?.toLowerCase().includes(search));
        })
        .sort((left, right) =>
          right.latestReportedAt.localeCompare(left.latestReportedAt),
        );

      const from = (query.page - 1) * query.pageSize;
      return {
        items: cases.slice(from, from + query.pageSize),
        page: query.page,
        pageSize: query.pageSize,
        total: cases.length,
      };
    },
    getReportCase: async (
      targetType: ReportTargetType,
      targetId: string,
    ) => {
      const reportCase = await repository.getReportCaseDetail(
        targetType,
        targetId,
      );
      if (!reportCase) {
        throw new AdminNotFoundError('Report case not found.');
      }
      return reportCase;
    },
    decideReportCase: async (
      targetType: ReportTargetType,
      targetId: string,
      input: ReportCaseDecisionInput,
    ) => {
      const reason = input.reason.trim();
      await repository.decideReportCase(targetType, targetId, {
        ...input,
        reason:
          input.decision === 'retain' && reason.length === 0
            ? REPORT_RETAIN_AUDIT_REASON
            : reason,
      });
    },
    listAppeals: async (query: AppealListQuery) =>
      repository.listAppeals({
        ...query,
        search: query.search.trim(),
      }),
    getAppeal: async (appealId: string) => {
      const appeal = await repository.getAppealDetail(appealId);
      if (!appeal) {
        throw new AdminNotFoundError('Appeal not found.');
      }
      return appeal;
    },
    decideAppeal: async (
      appealId: string,
      input: AppealDecisionInput,
    ) => {
      await repository.decideAppeal(appealId, {
        ...input,
        reason: input.reason.trim(),
      });
    },
    listModerationCases: async (query: AiModerationListQuery) =>
      repository.listModerationCases({
        ...query,
        search: query.search.trim(),
      }),
    getModerationCase: async (caseId: string) => {
      const moderationCase = await repository.getModerationCase(caseId);
      if (!moderationCase) {
        throw new AdminNotFoundError('Moderation case not found.');
      }
      return moderationCase;
    },
    decideModerationCase: async (
      caseId: string,
      input: AiModerationDecisionInput,
    ) => {
      await repository.decideModerationCase(caseId, {
        ...input,
        reason: input.reason.trim(),
      });
    },
  };
}
