import { adminApi } from '../../lib/adminApi';
import type { AiFlaggedPage, AiFlaggedStatus } from './aiFlaggedTypes';

export function loadAiFlaggedCases(status: AiFlaggedStatus) {
  return adminApi.get<AiFlaggedPage>('/admin/moderation-cases', {
    status,
    page: 1,
    pageSize: 20,
  });
}

export function decideAiFlaggedCase(
  caseId: string,
  decision: 'approved' | 'rejected',
  reason: string,
) {
  return adminApi.post<void>(`/admin/moderation-cases/${caseId}/decision`, {
    decision,
    reason,
  });
}
