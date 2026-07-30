export type AccountStatus = 'active' | 'suspended';
export type CreatorRequestStatus = 'pending' | 'approved' | 'rejected';
export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed';
export type AppealStatus = 'pending' | 'approved' | 'rejected';
export type ReportTargetType = 'post' | 'comment';
export type UserAccountState = AccountStatus | 'deleted';
export type CreatorFilter = 'all' | 'creator' | 'member';

export type PageRequest = {
  page: number;
  pageSize: number;
};

export type PageResult<T> = {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
};

export type DecisionInput = {
  decision: string;
  reason: string;
};

export type AuditView = {
  id: string;
  adminId: string;
  adminEmail: string | null;
  actionType: string;
  targetType: string;
  targetId: string;
  reason: string;
  createdAt: string;
};

export type OverviewView = {
  pendingCreatorRequests: number;
  pendingReportCases: number;
  pendingAppeals: number;
  recentDecisions: AuditView[];
};

export type OverviewReportRow = {
  targetType: string;
  targetId: string;
  reporterId: string | null;
  status: ReportStatus;
};

export type OverviewAuditRow = AuditView;

export type OverviewSnapshot = {
  pendingCreatorRequests: number;
  pendingAppeals: number;
  reportRows: OverviewReportRow[];
  recentAuditRows: OverviewAuditRow[];
};

export type PostSummaryView = {
  id: string;
  title: string;
  content: string;
  tags: string[];
  moderationStatus: string;
  publishedAt: string | null;
  createdAt: string;
};

export type UserSummaryView = {
  id: string;
  name: string;
  email: string;
  avatarUrl: string | null;
  bio: string | null;
  isContentCreator: boolean;
  isAdmin: boolean;
  accountStatus: UserAccountState;
  createdAt: string;
};

export type UserDetailView = UserSummaryView & {
  emailVerified: boolean | null;
  recentPosts: PostSummaryView[];
  recentDecisions: AuditView[];
};

export type UserListQuery = PageRequest & {
  search: string;
  accountStatus?: AccountStatus;
  creator: CreatorFilter;
};

export type UserAccountStatusInput = {
  status: AccountStatus;
  reason: string;
};

export type UserCreatorStatusInput = {
  isCreator: boolean;
  reason: string;
};

export type CreatorRequestSummaryView = {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  avatarUrl: string | null;
  reason: string | null;
  status: CreatorRequestStatus;
  createdAt: string;
  reviewedAt: string | null;
};

export type CreatorRequestDetailView = CreatorRequestSummaryView & {
  accountStatus: UserAccountState;
  isContentCreator: boolean;
  memberSince: string;
  bio: string | null;
  adminNote: string | null;
  reviewedBy: string | null;
  recentPosts: PostSummaryView[];
  recentDecisions: AuditView[];
};

export type CreatorRequestListQuery = PageRequest & {
  search: string;
  status: CreatorRequestStatus;
};

export type CreatorRequestDecisionInput = {
  decision: 'approved' | 'rejected';
  reason: string;
};

export type AdminRepository = {
  getOverviewSnapshot: () => Promise<OverviewSnapshot>;
  listUsers: (query: UserListQuery) => Promise<PageResult<UserSummaryView>>;
  getUserDetail: (userId: string) => Promise<UserDetailView | null>;
  setUserAccountStatus: (
    userId: string,
    input: UserAccountStatusInput,
  ) => Promise<void>;
  setUserCreatorStatus: (
    userId: string,
    input: UserCreatorStatusInput,
  ) => Promise<void>;
  listCreatorRequests: (
    query: CreatorRequestListQuery,
  ) => Promise<PageResult<CreatorRequestSummaryView>>;
  getCreatorRequestDetail: (
    requestId: string,
  ) => Promise<CreatorRequestDetailView | null>;
  decideCreatorRequest: (
    requestId: string,
    input: CreatorRequestDecisionInput,
  ) => Promise<void>;
};

export type AdminService = {
  getOverview: () => Promise<OverviewView>;
  listUsers: (
    query: UserListQuery,
  ) => Promise<PageResult<UserSummaryView>>;
  getUser: (userId: string) => Promise<UserDetailView>;
  setUserAccountStatus: (
    userId: string,
    input: UserAccountStatusInput,
  ) => Promise<void>;
  setUserCreatorStatus: (
    userId: string,
    input: UserCreatorStatusInput,
  ) => Promise<void>;
  listCreatorRequests: (
    query: CreatorRequestListQuery,
  ) => Promise<PageResult<CreatorRequestSummaryView>>;
  getCreatorRequest: (
    requestId: string,
  ) => Promise<CreatorRequestDetailView>;
  decideCreatorRequest: (
    requestId: string,
    input: CreatorRequestDecisionInput,
  ) => Promise<void>;
};

export class AdminValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminValidationError';
  }
}

export class AdminNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminNotFoundError';
  }
}

export class AdminConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminConflictError';
  }
}
