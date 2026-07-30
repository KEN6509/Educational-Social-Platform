export type AccountStatus = 'active' | 'suspended';
export type CreatorRequestStatus = 'pending' | 'approved' | 'rejected';
export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed';
export type AppealStatus = 'pending' | 'approved' | 'rejected';
export type ReportTargetType = 'post' | 'comment';

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

export type AdminRepository = {
  getOverviewSnapshot: () => Promise<OverviewSnapshot>;
};

export type AdminService = {
  getOverview: () => Promise<OverviewView>;
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
