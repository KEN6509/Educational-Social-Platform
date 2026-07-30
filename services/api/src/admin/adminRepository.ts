import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AdminRepository,
  OverviewAuditRow,
  OverviewReportRow,
} from './adminTypes.js';

function assertQuerySucceeded(
  error: { message: string } | null,
): asserts error is null {
  if (error) {
    throw new Error('Unable to read administrator data.');
  }
}

export function createAdminRepository(
  client: SupabaseClient,
): AdminRepository {
  return {
    getOverviewSnapshot: async () => {
      const [
        creatorRequestResult,
        appealResult,
        reportResult,
        auditResult,
      ] = await Promise.all([
        client
          .from('content_creator_requests')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'pending'),
        client
          .from('post_appeals')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'pending'),
        client
          .from('reports')
          .select('target_type, target_id, reporter_id, status')
          .in('status', ['open', 'reviewing']),
        client
          .from('admin_action_audit')
          .select(
            'id, admin_id, action_type, target_type, target_id, reason, created_at',
          )
          .order('created_at', { ascending: false })
          .limit(8),
      ]);

      assertQuerySucceeded(creatorRequestResult.error);
      assertQuerySucceeded(appealResult.error);
      assertQuerySucceeded(reportResult.error);
      assertQuerySucceeded(auditResult.error);

      const reportRows: OverviewReportRow[] = (reportResult.data ?? []).map(
        (row) => ({
          targetType: row.target_type,
          targetId: row.target_id,
          reporterId: row.reporter_id,
          status: row.status,
        }),
      );

      const recentAuditRows: OverviewAuditRow[] = (
        auditResult.data ?? []
      ).map((row) => ({
        id: row.id,
        adminId: row.admin_id,
        adminEmail: null,
        actionType: row.action_type,
        targetType: row.target_type,
        targetId: row.target_id,
        reason: row.reason,
        createdAt: row.created_at,
      }));

      return {
        pendingCreatorRequests: creatorRequestResult.count ?? 0,
        pendingAppeals: appealResult.count ?? 0,
        reportRows,
        recentAuditRows,
      };
    },
  };
}
