export type AiFlaggedStatus = 'pending' | 'approved' | 'rejected';

export type AiFlaggedCase = {
  id: string;
  targetType: 'post' | 'comment';
  targetId: string;
  moderationRevision: number;
  authorName: string;
  authorEmail: string;
  submittedAt: string;
  title: string | null;
  content: string;
  imageUrls: string[];
  riskScore: number;
  categoryScores: Record<string, number>;
  evidence: string[];
  userReason: string;
  model: string;
  status: AiFlaggedStatus;
  decisionReason: string | null;
  decidedAt: string | null;
};

export type AiFlaggedPage = {
  items: AiFlaggedCase[];
  page: number;
  pageSize: number;
  total: number;
};
