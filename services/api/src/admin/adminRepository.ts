import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AdminRepository,
  AuditView,
  CreatorRequestDetailView,
  CreatorRequestListQuery,
  CreatorRequestSummaryView,
  OverviewAuditRow,
  OverviewReportRow,
  PageResult,
  PostSummaryView,
  UserDetailView,
  UserListQuery,
  UserSummaryView,
} from './adminTypes.js';
import {
  AdminConflictError,
  AdminNotFoundError,
  AdminValidationError,
} from './adminTypes.js';

function assertQuerySucceeded(
  error: { message: string } | null,
): asserts error is null {
  if (error) {
    throw new Error('Unable to read administrator data.');
  }
}

function escapeSearchTerm(value: string) {
  return value.replace(/[,%()\\]/g, ' ').replace(/\s+/g, ' ').trim();
}

function mapUser(row: Record<string, unknown>): UserSummaryView {
  return {
    id: String(row.id),
    name: String(row.name),
    email: String(row.email),
    avatarUrl: typeof row.avatar_url === 'string' ? row.avatar_url : null,
    bio: typeof row.bio === 'string' ? row.bio : null,
    isContentCreator: row.is_content_creator === true,
    isAdmin: row.is_admin === true,
    accountStatus: row.account_status as UserSummaryView['accountStatus'],
    createdAt: String(row.created_at),
  };
}

function mapPost(row: Record<string, unknown>): PostSummaryView {
  return {
    id: String(row.id),
    title: String(row.title ?? ''),
    content: String(row.content ?? ''),
    tags: Array.isArray(row.tags)
      ? row.tags.filter((tag): tag is string => typeof tag === 'string')
      : [],
    moderationStatus: String(row.moderation_status),
    publishedAt:
      typeof row.published_at === 'string' ? row.published_at : null,
    createdAt: String(row.created_at),
  };
}

function mapAudit(row: Record<string, unknown>): AuditView {
  return {
    id: String(row.id),
    adminId: String(row.admin_id),
    adminEmail: null,
    actionType: String(row.action_type),
    targetType: String(row.target_type),
    targetId: String(row.target_id),
    reason: String(row.reason),
    createdAt: String(row.created_at),
  };
}

function throwRpcError(error: { message: string } | null) {
  if (!error) {
    return;
  }

  const message = error.message.toLowerCase();
  if (message.includes('not found')) {
    throw new AdminNotFoundError(error.message);
  }
  if (
    message.includes('already') ||
    message.includes('no longer') ||
    message.includes('cannot be changed')
  ) {
    throw new AdminConflictError(error.message);
  }
  if (
    message.includes('must be') ||
    message.includes('cannot suspend') ||
    message.includes('required')
  ) {
    throw new AdminValidationError(error.message);
  }

  throw new Error('Unable to complete the administrator decision.');
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
    listUsers: async (
      query: UserListQuery,
    ): Promise<PageResult<UserSummaryView>> => {
      const from = (query.page - 1) * query.pageSize;
      const to = from + query.pageSize - 1;
      let request = client
        .from('profiles')
        .select(
          'id, name, email, avatar_url, bio, is_content_creator, is_admin, account_status, created_at',
          { count: 'exact' },
        )
        .order('created_at', { ascending: false })
        .order('id', { ascending: true })
        .range(from, to);

      const search = escapeSearchTerm(query.search);
      if (search) {
        request = request.or(
          `name.ilike.%${search}%,email.ilike.%${search}%`,
        );
      }
      if (query.accountStatus) {
        request = request.eq('account_status', query.accountStatus);
      }
      if (query.creator === 'creator') {
        request = request.eq('is_content_creator', true);
      } else if (query.creator === 'member') {
        request = request.eq('is_content_creator', false);
      }

      const { data, error, count } = await request;
      assertQuerySucceeded(error);

      return {
        items: (data ?? []).map((row) => mapUser(row)),
        page: query.page,
        pageSize: query.pageSize,
        total: count ?? 0,
      };
    },
    getUserDetail: async (userId: string): Promise<UserDetailView | null> => {
      const profileResult = await client
        .from('profiles')
        .select(
          'id, name, email, avatar_url, bio, is_content_creator, is_admin, account_status, created_at',
        )
        .eq('id', userId)
        .maybeSingle();

      assertQuerySucceeded(profileResult.error);
      if (!profileResult.data) {
        return null;
      }

      const [postsResult, auditResult] = await Promise.all([
        client
          .from('posts')
          .select(
            'id, title, content, tags, moderation_status, published_at, created_at',
          )
          .eq('author_id', userId)
          .eq('moderation_status', 'approved')
          .order('published_at', { ascending: false, nullsFirst: false })
          .limit(5),
        client
          .from('admin_action_audit')
          .select(
            'id, admin_id, action_type, target_type, target_id, reason, created_at',
          )
          .eq('target_type', 'user')
          .eq('target_id', userId)
          .order('created_at', { ascending: false })
          .limit(10),
      ]);

      assertQuerySucceeded(postsResult.error);
      assertQuerySucceeded(auditResult.error);

      return {
        ...mapUser(profileResult.data),
        emailVerified: null,
        recentPosts: (postsResult.data ?? []).map((row) => mapPost(row)),
        recentDecisions: (auditResult.data ?? []).map((row) =>
          mapAudit(row),
        ),
      };
    },
    setUserAccountStatus: async (userId, input) => {
      const { error } = await client.rpc('set_user_account_status', {
        p_user_id: userId,
        p_status: input.status,
        p_reason: input.reason,
      });
      throwRpcError(error);
    },
    setUserCreatorStatus: async (userId, input) => {
      const { error } = await client.rpc('set_user_creator_status', {
        p_user_id: userId,
        p_is_creator: input.isCreator,
        p_reason: input.reason,
      });
      throwRpcError(error);
    },
    listCreatorRequests: async (
      query: CreatorRequestListQuery,
    ): Promise<PageResult<CreatorRequestSummaryView>> => {
      let userIds: string[] | undefined;
      const search = escapeSearchTerm(query.search);

      if (search) {
        const profileSearch = await client
          .from('profiles')
          .select('id')
          .or(`name.ilike.%${search}%,email.ilike.%${search}%`)
          .limit(100);
        assertQuerySucceeded(profileSearch.error);
        userIds = (profileSearch.data ?? []).map((row) => row.id);

        if (userIds.length === 0) {
          return {
            items: [],
            page: query.page,
            pageSize: query.pageSize,
            total: 0,
          };
        }
      }

      const from = (query.page - 1) * query.pageSize;
      const to = from + query.pageSize - 1;
      let request = client
        .from('content_creator_requests')
        .select(
          'id, user_id, reason, status, reviewed_by, reviewed_at, admin_note, created_at',
          { count: 'exact' },
        )
        .eq('status', query.status)
        .order('created_at', { ascending: false })
        .order('id', { ascending: true })
        .range(from, to);

      if (userIds) {
        request = request.in('user_id', userIds);
      }

      const requestResult = await request;
      assertQuerySucceeded(requestResult.error);
      const requests = requestResult.data ?? [];
      const pageUserIds = [...new Set(requests.map((row) => row.user_id))];
      const profileResult =
        pageUserIds.length === 0
          ? { data: [], error: null }
          : await client
              .from('profiles')
              .select('id, name, email, avatar_url')
              .in('id', pageUserIds);
      assertQuerySucceeded(profileResult.error);
      const profiles = new Map(
        (profileResult.data ?? []).map((row) => [row.id, row]),
      );

      return {
        items: requests.map((requestRow) => {
          const profile = profiles.get(requestRow.user_id);
          return {
            id: requestRow.id,
            userId: requestRow.user_id,
            userName: profile?.name ?? 'Unknown user',
            userEmail: profile?.email ?? '',
            avatarUrl: profile?.avatar_url ?? null,
            reason: requestRow.reason,
            status: requestRow.status,
            createdAt: requestRow.created_at,
            reviewedAt: requestRow.reviewed_at,
          };
        }),
        page: query.page,
        pageSize: query.pageSize,
        total: requestResult.count ?? 0,
      };
    },
    getCreatorRequestDetail: async (
      requestId: string,
    ): Promise<CreatorRequestDetailView | null> => {
      const requestResult = await client
        .from('content_creator_requests')
        .select(
          'id, user_id, reason, status, reviewed_by, reviewed_at, admin_note, created_at',
        )
        .eq('id', requestId)
        .maybeSingle();
      assertQuerySucceeded(requestResult.error);

      if (!requestResult.data) {
        return null;
      }

      const requestRow = requestResult.data;
      const [profileResult, postsResult, auditResult] = await Promise.all([
        client
          .from('profiles')
          .select(
            'id, name, email, avatar_url, bio, is_content_creator, account_status, created_at',
          )
          .eq('id', requestRow.user_id)
          .maybeSingle(),
        client
          .from('posts')
          .select(
            'id, title, content, tags, moderation_status, published_at, created_at',
          )
          .eq('author_id', requestRow.user_id)
          .eq('moderation_status', 'approved')
          .order('published_at', { ascending: false, nullsFirst: false })
          .limit(5),
        client
          .from('admin_action_audit')
          .select(
            'id, admin_id, action_type, target_type, target_id, reason, created_at',
          )
          .eq('target_type', 'creator_request')
          .eq('target_id', requestId)
          .order('created_at', { ascending: false })
          .limit(10),
      ]);
      assertQuerySucceeded(profileResult.error);
      assertQuerySucceeded(postsResult.error);
      assertQuerySucceeded(auditResult.error);

      if (!profileResult.data) {
        return null;
      }

      const profile = profileResult.data;
      return {
        id: requestRow.id,
        userId: requestRow.user_id,
        userName: profile.name,
        userEmail: profile.email,
        avatarUrl: profile.avatar_url,
        reason: requestRow.reason,
        status: requestRow.status,
        createdAt: requestRow.created_at,
        reviewedAt: requestRow.reviewed_at,
        accountStatus: profile.account_status,
        isContentCreator: profile.is_content_creator,
        memberSince: profile.created_at,
        bio: profile.bio,
        adminNote: requestRow.admin_note,
        reviewedBy: requestRow.reviewed_by,
        recentPosts: (postsResult.data ?? []).map((row) => mapPost(row)),
        recentDecisions: (auditResult.data ?? []).map((row) =>
          mapAudit(row),
        ),
      };
    },
    decideCreatorRequest: async (requestId, input) => {
      const { error } = await client.rpc('review_creator_request', {
        p_request_id: requestId,
        p_decision: input.decision,
        p_reason: input.reason,
      });
      throwRpcError(error);
    },
  };
}
