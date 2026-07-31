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
  coverImageUrl: string | null;
  imageCount: number;
  commentCount: number;
};

export type AdminCommentView = {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatarUrl: string | null;
  isCreator: boolean;
  content: string;
  createdAt: string;
  likeCount: number;
  replies: AdminCommentView[];
};

export type AdminPostDetailView = PostSummaryView & {
  authorId: string;
  authorName: string;
  authorAvatarUrl: string | null;
  images: Array<{ url: string; position: number }>;
  comments: AdminCommentView[];
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
  publishedPostCount: number;
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

export type ReportCaseRow = {
  id: string;
  targetType: ReportTargetType;
  targetId: string;
  reporterId: string | null;
  reason: string;
  description: string | null;
  status: ReportStatus;
  reviewedBy: string | null;
  reviewedAt: string | null;
  resolutionNote: string | null;
  createdAt: string;
  targetTitle: string | null;
  targetExcerpt: string;
  ownerName: string;
};

export type ReportReasonCount = {
  reason: string;
  count: number;
};

export type ReportCaseSummaryView = {
  targetType: ReportTargetType;
  targetId: string;
  targetTitle: string | null;
  targetExcerpt: string;
  ownerName: string;
  status: ReportStatus;
  totalReports: number;
  uniqueReporters: number;
  reasonCounts: ReportReasonCount[];
  latestReportedAt: string;
};

export type ReportHistoryView = {
  id: string;
  reporterId: string | null;
  reason: string;
  description: string | null;
  status: ReportStatus;
  createdAt: string;
  reviewedAt: string | null;
  resolutionNote: string | null;
};

export type ReportCaseDetailView = ReportCaseSummaryView & {
  ownerId: string | null;
  ownerEmail: string | null;
  content: string | null;
  moderationStatus: string | null;
  publishedAt: string | null;
  reports: ReportHistoryView[];
  recentDecisions: AuditView[];
};

export type ReportCaseListQuery = PageRequest & {
  search: string;
  status: ReportStatus;
  targetType?: ReportTargetType;
};

export type ReportCaseDecisionInput = {
  decision: 'retain' | 'remove';
  reason: string;
};

export type AppealSummaryView = {
  id: string;
  postId: string;
  userId: string;
  userName: string;
  userEmail: string;
  postTitle: string;
  reason: string;
  status: AppealStatus;
  createdAt: string;
  reviewedAt: string | null;
};

export type AppealDetailView = AppealSummaryView & {
  postContent: string | null;
  moderationStatus: string | null;
  originalModerationReason: string | null;
  originalReviewedAt: string | null;
  aiToxicityScore: number | null;
  adminNote: string | null;
  reviewedBy: string | null;
  recentDecisions: AuditView[];
};

export type AppealListQuery = PageRequest & {
  search: string;
  status: AppealStatus;
};

export type AppealDecisionInput = {
  decision: 'approved' | 'rejected';
  reason: string;
};

export type AdminRepository = {
  getOverviewSnapshot: () => Promise<OverviewSnapshot>;
  listUsers: (query: UserListQuery) => Promise<PageResult<UserSummaryView>>;
  getUserDetail: (userId: string) => Promise<UserDetailView | null>;
  listUserPublishedPosts: (userId: string) => Promise<PostSummaryView[]>;
  getPostDetail: (postId: string) => Promise<AdminPostDetailView | null>;
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
  getReportCaseRows: (
    query: ReportCaseListQuery,
  ) => Promise<ReportCaseRow[]>;
  getReportCaseDetail: (
    targetType: ReportTargetType,
    targetId: string,
  ) => Promise<ReportCaseDetailView | null>;
  decideReportCase: (
    targetType: ReportTargetType,
    targetId: string,
    input: ReportCaseDecisionInput,
  ) => Promise<void>;
  listAppeals: (
    query: AppealListQuery,
  ) => Promise<PageResult<AppealSummaryView>>;
  getAppealDetail: (
    appealId: string,
  ) => Promise<AppealDetailView | null>;
  decideAppeal: (
    appealId: string,
    input: AppealDecisionInput,
  ) => Promise<void>;
};

export type AdminService = {
  getOverview: () => Promise<OverviewView>;
  listUsers: (
    query: UserListQuery,
  ) => Promise<PageResult<UserSummaryView>>;
  getUser: (userId: string) => Promise<UserDetailView>;
  listUserPosts: (userId: string) => Promise<PostSummaryView[]>;
  getPost: (postId: string) => Promise<AdminPostDetailView>;
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
  listReportCases: (
    query: ReportCaseListQuery,
  ) => Promise<PageResult<ReportCaseSummaryView>>;
  getReportCase: (
    targetType: ReportTargetType,
    targetId: string,
  ) => Promise<ReportCaseDetailView>;
  decideReportCase: (
    targetType: ReportTargetType,
    targetId: string,
    input: ReportCaseDecisionInput,
  ) => Promise<void>;
  listAppeals: (
    query: AppealListQuery,
  ) => Promise<PageResult<AppealSummaryView>>;
  getAppeal: (appealId: string) => Promise<AppealDetailView>;
  decideAppeal: (
    appealId: string,
    input: AppealDecisionInput,
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
