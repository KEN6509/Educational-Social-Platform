export type AiFlaggedStatus = 'pending' | 'approved' | 'rejected';

export type AiFlaggedCase = {
  id: string;
  targetType: 'post' | 'comment';
  authorName: string;
  authorEmail: string;
  submittedAt: string;
  title: string | null;
  content: string;
  imageUrls: string[];
  riskScore: number;
  evidence: string[];
  status: AiFlaggedStatus;
};
