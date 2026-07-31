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
          .limit(15),
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
    getReportCaseRows: async (query) => {
      let reportRequest = client
        .from('reports')
        .select(
          'id, reporter_id, target_type, target_id, reason, description, status, reviewed_by, reviewed_at, resolution_note, created_at',
        )
        .eq('status', query.status)
        .order('created_at', { ascending: false })
        .limit(1000);

      if (query.targetType) {
        reportRequest = reportRequest.eq('target_type', query.targetType);
      } else {
        reportRequest = reportRequest.in('target_type', ['post', 'comment']);
      }

      const reportResult = await reportRequest;
      assertQuerySucceeded(reportResult.error);
      const reports = reportResult.data ?? [];
      const postIds = [
        ...new Set(
          reports
            .filter((row) => row.target_type === 'post')
            .map((row) => row.target_id),
        ),
      ];
      const commentIds = [
        ...new Set(
          reports
            .filter((row) => row.target_type === 'comment')
            .map((row) => row.target_id),
        ),
      ];

      const postResult =
        postIds.length === 0
          ? { data: [], error: null }
          : await client
              .from('posts')
              .select('id, author_id, title, content')
              .in('id', postIds);
      const commentResult =
        commentIds.length === 0
          ? { data: [], error: null }
          : await client
              .from('comments')
              .select('id, author_id, content')
              .in('id', commentIds);
      assertQuerySucceeded(postResult.error);
      assertQuerySucceeded(commentResult.error);

      const posts = new Map(
        (postResult.data ?? []).map((row) => [row.id, row]),
      );
      const comments = new Map(
        (commentResult.data ?? []).map((row) => [row.id, row]),
      );
      const ownerIds = [
        ...new Set([
          ...(postResult.data ?? []).map((row) => row.author_id),
          ...(commentResult.data ?? []).map((row) => row.author_id),
        ]),
      ];
      const profileResult =
        ownerIds.length === 0
          ? { data: [], error: null }
          : await client
              .from('profiles')
              .select('id, name')
              .in('id', ownerIds);
      assertQuerySucceeded(profileResult.error);
      const owners = new Map(
        (profileResult.data ?? []).map((row) => [row.id, row.name]),
      );

      return reports
        .filter(
          (row) =>
            row.target_type === 'post' || row.target_type === 'comment',
        )
        .map((row) => {
          const target =
            row.target_type === 'post'
              ? posts.get(row.target_id)
              : comments.get(row.target_id);
          return {
            id: row.id,
            targetType: row.target_type,
            targetId: row.target_id,
            reporterId: row.reporter_id,
            reason: row.reason,
            description: row.description,
            status: row.status,
            reviewedBy: row.reviewed_by,
            reviewedAt: row.reviewed_at,
            resolutionNote: row.resolution_note,
            createdAt: row.created_at,
            targetTitle:
              row.target_type === 'post' &&
              target &&
              'title' in target
                ? typeof target.title === 'string'
                  ? target.title
                  : null
                : null,
            targetExcerpt: target?.content ?? 'Content is unavailable.',
            ownerName: target
              ? owners.get(target.author_id) ?? 'Unknown owner'
              : 'Unavailable content',
          };
        });
    },
    getReportCaseDetail: async (targetType, targetId) => {
      const reportResult = await client
        .from('reports')
        .select(
          'id, reporter_id, reason, description, status, reviewed_at, resolution_note, created_at',
        )
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .order('created_at', { ascending: true });
      assertQuerySucceeded(reportResult.error);

      if (!reportResult.data || reportResult.data.length === 0) {
        return null;
      }

      const targetResult =
        targetType === 'post'
          ? await client
              .from('posts')
              .select(
                'id, author_id, title, content, moderation_status, published_at',
              )
              .eq('id', targetId)
              .maybeSingle()
          : await client
              .from('comments')
              .select(
                'id, author_id, post_id, content, moderation_status, created_at',
              )
              .eq('id', targetId)
              .maybeSingle();
      assertQuerySucceeded(targetResult.error);
      const target = targetResult.data;

      const [ownerResult, auditResult] = await Promise.all([
        target
          ? client
              .from('profiles')
              .select('id, name, email')
              .eq('id', target.author_id)
              .maybeSingle()
          : Promise.resolve({ data: null, error: null }),
        client
          .from('admin_action_audit')
          .select(
            'id, admin_id, action_type, target_type, target_id, reason, created_at',
          )
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .order('created_at', { ascending: false })
          .limit(10),
      ]);
      assertQuerySucceeded(ownerResult.error);
      assertQuerySucceeded(auditResult.error);

      const reports = reportResult.data;
      const reporterIds = new Set(
        reports
          .map((row) => row.reporter_id)
          .filter((id): id is string => Boolean(id)),
      );
      const reasonMap = new Map<string, number>();
      for (const report of reports) {
        reasonMap.set(
          report.reason,
          (reasonMap.get(report.reason) ?? 0) + 1,
        );
      }
      const latest = reports.at(-1)!;

      return {
        targetType,
        targetId,
        targetTitle:
          targetType === 'post' && target && 'title' in target
            ? target.title ?? null
            : null,
        targetExcerpt: target?.content ?? 'Content is unavailable.',
        ownerName: ownerResult.data?.name ?? 'Unavailable content',
        status: latest.status,
        totalReports: reports.length,
        uniqueReporters: reporterIds.size,
        reasonCounts: [...reasonMap.entries()]
          .map(([reason, count]) => ({ reason, count }))
          .sort(
            (left, right) =>
              right.count - left.count ||
              left.reason.localeCompare(right.reason),
          ),
        latestReportedAt: latest.created_at,
        ownerId: target?.author_id ?? null,
        ownerEmail: ownerResult.data?.email ?? null,
        content: target?.content ?? null,
        moderationStatus: target?.moderation_status ?? null,
        publishedAt:
          targetType === 'post' && target && 'published_at' in target
            ? target.published_at ?? null
            : null,
        reports: reports.map((row) => ({
          id: row.id,
          reporterId: row.reporter_id,
          reason: row.reason,
          description: row.description,
          status: row.status,
          createdAt: row.created_at,
          reviewedAt: row.reviewed_at,
          resolutionNote: row.resolution_note,
        })),
        recentDecisions: (auditResult.data ?? []).map((row) =>
          mapAudit(row),
        ),
      };
    },
    decideReportCase: async (targetType, targetId, input) => {
      const { error } = await client.rpc('decide_report_case', {
        p_target_type: targetType,
        p_target_id: targetId,
        p_decision: input.decision,
        p_reason: input.reason,
      });
      throwRpcError(error);
    },
    listAppeals: async (query) => {
      const from = (query.page - 1) * query.pageSize;
      const to = from + query.pageSize - 1;
      const appealResult = await client
        .from('post_appeals')
        .select(
          'id, post_id, user_id, reason, status, reviewed_at, created_at',
          { count: 'exact' },
        )
        .eq('status', query.status)
        .order('created_at', { ascending: false })
        .range(from, to);
      assertQuerySucceeded(appealResult.error);
      const appeals = appealResult.data ?? [];
      const userIds = [...new Set(appeals.map((row) => row.user_id))];
      const postIds = [...new Set(appeals.map((row) => row.post_id))];
      const [profileResult, postResult] = await Promise.all([
        userIds.length === 0
          ? Promise.resolve({ data: [], error: null })
          : client
              .from('profiles')
              .select('id, name, email')
              .in('id', userIds),
        postIds.length === 0
          ? Promise.resolve({ data: [], error: null })
          : client.from('posts').select('id, title').in('id', postIds),
      ]);
      assertQuerySucceeded(profileResult.error);
      assertQuerySucceeded(postResult.error);
      const profiles = new Map(
        (profileResult.data ?? []).map((row) => [row.id, row]),
      );
      const posts = new Map(
        (postResult.data ?? []).map((row) => [row.id, row]),
      );
      const search = query.search.trim().toLowerCase();
      const items = appeals
        .map((row) => {
          const profile = profiles.get(row.user_id);
          const post = posts.get(row.post_id);
          return {
            id: row.id,
            postId: row.post_id,
            userId: row.user_id,
            userName: profile?.name ?? 'Unknown user',
            userEmail: profile?.email ?? '',
            postTitle: post?.title ?? 'Unavailable post',
            reason: row.reason,
            status: row.status,
            createdAt: row.created_at,
            reviewedAt: row.reviewed_at,
          };
        })
        .filter((item) =>
          search
            ? [item.userName, item.userEmail, item.postTitle].some((value) =>
                value.toLowerCase().includes(search),
              )
            : true,
        );

      return {
        items,
        page: query.page,
        pageSize: query.pageSize,
        total: search ? items.length : appealResult.count ?? 0,
      };
    },
    getAppealDetail: async (appealId) => {
      const appealResult = await client
        .from('post_appeals')
        .select(
          'id, post_id, user_id, reason, status, reviewed_by, reviewed_at, admin_note, created_at',
        )
        .eq('id', appealId)
        .maybeSingle();
      assertQuerySucceeded(appealResult.error);
      if (!appealResult.data) {
        return null;
      }

      const appeal = appealResult.data;
      const [profileResult, postResult, auditResult] = await Promise.all([
        client
          .from('profiles')
          .select('id, name, email')
          .eq('id', appeal.user_id)
          .maybeSingle(),
        client
          .from('posts')
          .select(
            'id, title, content, moderation_status, moderation_reason, reviewed_at, ai_toxicity_score',
          )
          .eq('id', appeal.post_id)
          .maybeSingle(),
        client
          .from('admin_action_audit')
          .select(
            'id, admin_id, action_type, target_type, target_id, reason, created_at',
          )
          .eq('target_type', 'post_appeal')
          .eq('target_id', appealId)
          .order('created_at', { ascending: false })
          .limit(10),
      ]);
      assertQuerySucceeded(profileResult.error);
      assertQuerySucceeded(postResult.error);
      assertQuerySucceeded(auditResult.error);
      const profile = profileResult.data;
      const post = postResult.data;

      return {
        id: appeal.id,
        postId: appeal.post_id,
        userId: appeal.user_id,
        userName: profile?.name ?? 'Unknown user',
        userEmail: profile?.email ?? '',
        postTitle: post?.title ?? 'Unavailable post',
        reason: appeal.reason,
        status: appeal.status,
        createdAt: appeal.created_at,
        reviewedAt: appeal.reviewed_at,
        postContent: post?.content ?? null,
        moderationStatus: post?.moderation_status ?? null,
        originalModerationReason: post?.moderation_reason ?? null,
        originalReviewedAt: post?.reviewed_at ?? null,
        aiToxicityScore:
          typeof post?.ai_toxicity_score === 'number'
            ? post.ai_toxicity_score
            : post?.ai_toxicity_score
              ? Number(post.ai_toxicity_score)
              : null,
        adminNote: appeal.admin_note,
        reviewedBy: appeal.reviewed_by,
        recentDecisions: (auditResult.data ?? []).map((row) =>
          mapAudit(row),
        ),
      };
    },
    decideAppeal: async (appealId, input) => {
      const { error } = await client.rpc('decide_post_appeal', {
        p_appeal_id: appealId,
        p_decision: input.decision,
        p_reason: input.reason,
      });
      throwRpcError(error);
    },
  };
}
