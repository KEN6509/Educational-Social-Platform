export type PageResult<T> = {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
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
  accountStatus: 'active' | 'suspended' | 'deleted';
  createdAt: string;
};

export type UserDetailView = UserSummaryView & {
  emailVerified: boolean | null;
  publishedPostCount: number;
  recentPosts: PostSummaryView[];
  recentDecisions: AuditView[];
};

export type CreatorRequestSummaryView = {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  avatarUrl: string | null;
  reason: string | null;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
  reviewedAt: string | null;
};

export type CreatorRequestDetailView = CreatorRequestSummaryView & {
  accountStatus: 'active' | 'suspended' | 'deleted';
  isContentCreator: boolean;
  memberSince: string;
  bio: string | null;
  adminNote: string | null;
  reviewedBy: string | null;
  recentPosts: PostSummaryView[];
  recentDecisions: AuditView[];
};

export type ReportCaseSummaryView = {
  targetType: 'post' | 'comment';
  targetId: string;
  targetTitle: string | null;
  targetExcerpt: string;
  ownerName: string;
  status: 'pending_review' | 'resolved' | 'dismissed';
  totalReports: number;
  uniqueReporters: number;
  reasonCounts: Array<{ reason: string; count: number }>;
  latestReportedAt: string;
};

export type ReportCaseDetailView = ReportCaseSummaryView & {
  ownerId: string | null;
  ownerEmail: string | null;
  content: string | null;
  moderationStatus: string | null;
  publishedAt: string | null;
  reports: Array<{
    id: string;
    reporterId: string | null;
    reason: string;
    status: string;
    createdAt: string;
    reviewedAt: string | null;
    resolutionNote: string | null;
  }>;
  recentDecisions: AuditView[];
};

export type AppealSummaryView = {
  id: string;
  postId: string;
  userId: string;
  userName: string;
  userEmail: string;
  postTitle: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
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
