import { ArrowLeft, Filter, Search, UserRound } from 'lucide-react';
import {
  useCallback,
  useEffect,
  useState,
  type FormEvent,
} from 'react';

import { AsyncState } from '../../components/casework/AsyncState';
import { CaseworkList } from '../../components/casework/CaseworkList';
import { DecisionDialog } from '../../components/casework/DecisionDialog';
import { DecisionPanel } from '../../components/casework/DecisionPanel';
import {
  adminApi,
  AdminApiError,
  type AdminApi,
} from '../../lib/adminApi';
import type {
  AdminPostDetailView,
  PageResult,
  PostSummaryView,
  UserDetailView,
  UserSummaryView,
} from '../../types/admin';
import { UserDetail } from './UserDetail';
import { AllPostsModal } from './AllPostsModal';
import { PostDetailModal } from './PostDetailModal';

type Filters = {
  search: string;
  accountStatus: string;
  creator: string;
};

type Decision = { nextValue: boolean };

export function UsersPage({
  api = adminApi,
}: {
  api?: AdminApi;
}) {
  const [draft, setDraft] = useState<Filters>({
    search: '',
    accountStatus: '',
    creator: 'all',
  });
  const [filters, setFilters] = useState<Filters>({
    search: '',
    accountStatus: '',
    creator: 'all',
  });
  const [list, setList] = useState<PageResult<UserSummaryView> | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<UserDetailView | null>(null);
  const [listError, setListError] = useState<string | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [decision, setDecision] = useState<Decision | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [decisionError, setDecisionError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);
  const [mobileDetail, setMobileDetail] = useState(false);
  const [allPostsOpen, setAllPostsOpen] = useState(false);
  const [allPosts, setAllPosts] = useState<PostSummaryView[]>([]);
  const [allPostsLoading, setAllPostsLoading] = useState(false);
  const [allPostsError, setAllPostsError] = useState<string | null>(null);
  const [postDetailOpen, setPostDetailOpen] = useState(false);
  const [postDetail, setPostDetail] = useState<AdminPostDetailView | null>(null);
  const [postDetailLoading, setPostDetailLoading] = useState(false);
  const [postDetailError, setPostDetailError] = useState<string | null>(null);
  const [postDetailId, setPostDetailId] = useState<string | null>(null);
  const [postSource, setPostSource] = useState<'recent' | 'all' | null>(null);

  const loadList = useCallback(async () => {
    setListError(null);
    try {
      const result = await api.get<PageResult<UserSummaryView>>(
        '/admin/users',
        {
          page: 1,
          pageSize: 20,
          search: filters.search.trim(),
          accountStatus: filters.accountStatus || undefined,
          creator: filters.creator,
        },
      );
      setList(result);
      setSelectedId((current) =>
        result.items.some((item) => item.id === current)
          ? current
          : (result.items[0]?.id ?? null),
      );
    } catch (error) {
      setListError(messageOf(error, 'Users could not be loaded.'));
    }
  }, [api, filters, reload]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return;
    }
    let active = true;
    setDetail(null);
    setDetailError(null);
    void api
      .get<UserDetailView>(`/admin/users/${selectedId}`)
      .then((result) => {
        if (active) setDetail(result);
      })
      .catch((error: unknown) => {
        if (active) {
          setDetailError(
            messageOf(error, 'User details could not be loaded.'),
          );
        }
      });
    return () => {
      active = false;
    };
  }, [api, selectedId, reload]);

  useEffect(() => {
    setAllPostsOpen(false);
    setAllPosts([]);
    setAllPostsError(null);
    setPostDetailOpen(false);
    setPostDetail(null);
    setPostDetailError(null);
    setPostDetailId(null);
    setPostSource(null);
  }, [selectedId]);

  async function loadAllPosts(userId: string) {
    setAllPostsLoading(true);
    setAllPostsError(null);
    try {
      setAllPosts(
        await api.get<PostSummaryView[]>(`/admin/users/${userId}/posts`),
      );
    } catch (error) {
      setAllPostsError(
        messageOf(error, 'Published posts could not be loaded.'),
      );
    } finally {
      setAllPostsLoading(false);
    }
  }

  function openAllPosts() {
    if (!detail) return;
    setAllPostsOpen(true);
    if (allPosts.length === 0) void loadAllPosts(detail.id);
  }

  async function loadPost(postId: string) {
    setPostDetailLoading(true);
    setPostDetailError(null);
    try {
      setPostDetail(
        await api.get<AdminPostDetailView>(`/admin/posts/${postId}`),
      );
    } catch (error) {
      setPostDetailError(messageOf(error, 'Post details could not be loaded.'));
    } finally {
      setPostDetailLoading(false);
    }
  }

  function openPost(postId: string, source: 'recent' | 'all') {
    setPostSource(source);
    setPostDetailId(postId);
    setPostDetail(null);
    setPostDetailOpen(true);
    void loadPost(postId);
  }

  function closePostDetail() {
    setPostDetailOpen(false);
    setPostDetail(null);
    setPostDetailError(null);
    setPostDetailId(null);
    setPostSource(null);
  }

  function applyFilters(event: FormEvent) {
    event.preventDefault();
    setFilters({
      search: draft.search.trim(),
      accountStatus: draft.accountStatus,
      creator: draft.creator,
    });
  }

  async function confirmDecision() {
    if (!detail || !decision) return;
    setSubmitting(true);
    setDecisionError(null);
    try {
      await api.post(`/admin/users/${detail.id}/creator-status`, {
        isCreator: decision.nextValue,
        reason: reason.trim(),
      });
      setDecision(null);
      setReason('');
      setReload((value) => value + 1);
    } catch (error) {
      setDecision(null);
      setDecisionError(
        error instanceof AdminApiError && error.code === 'conflict'
          ? `${error.message} The account has been refreshed.`
          : messageOf(error, 'The decision could not be saved.'),
      );
      if (error instanceof AdminApiError && error.code === 'conflict') {
        setReload((value) => value + 1);
      }
    } finally {
      setSubmitting(false);
    }
  }

  const creatorButton = detail?.isContentCreator
    ? 'Remove creator'
    : 'Assign creator';

  return (
    <section className="min-h-screen bg-white">
      <header className="border-b border-slate-200 px-5 py-6 lg:px-8">
        <h1 className="text-3xl font-black tracking-tight">Users</h1>
        <p className="mt-1 text-sm text-slate-500">
          Review accounts, access, and creator status.
        </p>
      </header>

      <div className="grid min-h-[calc(100vh-7rem)] xl:grid-cols-[25rem_minmax(0,1fr)]">
        <aside
          className={`border-r border-slate-200 ${
            mobileDetail ? 'hidden xl:block' : 'block'
          }`}
        >
          <form className="border-b border-slate-200 p-4" onSubmit={applyFilters}>
            <label className="relative block">
              <span className="sr-only">Search users</span>
              <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-slate-400" />
              <input
                aria-label="Search users"
                className="h-10 w-full rounded-lg border border-slate-300 pl-9 pr-3 text-sm outline-none focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
                onChange={(event) =>
                  setDraft({ ...draft, search: event.target.value })
                }
                placeholder="Search name or email…"
                type="search"
                value={draft.search}
              />
            </label>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <label className="text-xs font-bold text-slate-500">
                Account status
                <select
                  className="mt-1 h-10 w-full rounded-lg border border-slate-300 bg-white px-2 text-sm"
                  onChange={(event) =>
                    setDraft({
                      ...draft,
                      accountStatus: event.target.value,
                    })
                  }
                  value={draft.accountStatus}
                >
                  <option value="">All accounts</option>
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                </select>
              </label>
              <label className="text-xs font-bold text-slate-500">
                Creator status
                <select
                  className="mt-1 h-10 w-full rounded-lg border border-slate-300 bg-white px-2 text-sm"
                  onChange={(event) =>
                    setDraft({ ...draft, creator: event.target.value })
                  }
                  value={draft.creator}
                >
                  <option value="all">All roles</option>
                  <option value="creator">Creators</option>
                  <option value="member">Members</option>
                </select>
              </label>
            </div>
            <button
              className="mt-3 inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg bg-slate-900 text-sm font-bold text-white"
              type="submit"
            >
              <Filter className="h-4 w-4" />
              Apply filters
            </button>
          </form>

          {!list && !listError ? <AsyncState state="loading" /> : null}
          {listError ? (
            <AsyncState
              errorMessage={listError}
              onRetry={() => setReload((value) => value + 1)}
              state="error"
            />
          ) : null}
          {list?.items.length === 0 ? (
            <AsyncState
              emptyMessage="No users match these filters."
              state="empty"
            />
          ) : null}
          {list?.items.length ? (
            <>
              <CaseworkList
                items={list.items.map((item) => ({
                  id: item.id,
                  title: item.name,
                  subtitle: `${item.email} · ${
                    item.isContentCreator ? 'Creator' : 'Member'
                  }`,
                  leading: item.avatarUrl ? (
                    <img
                      alt=""
                      className="h-10 w-10 rounded-full object-cover"
                      src={item.avatarUrl}
                    />
                  ) : (
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-slate-100 text-slate-500">
                      <UserRound className="h-5 w-5" />
                    </span>
                  ),
                }))}
                onSelect={(id) => {
                  setSelectedId(id);
                  setMobileDetail(true);
                }}
                selectedId={selectedId}
              />
              <p className="border-t border-slate-200 px-4 py-3 text-xs text-slate-500">
                {list.total} user{list.total === 1 ? '' : 's'}
              </p>
            </>
          ) : null}
        </aside>

        <div
          className={`min-w-0 ${
            mobileDetail ? 'block' : 'hidden xl:block'
          }`}
        >
          <button
            className="m-4 inline-flex h-10 items-center gap-2 rounded-lg border border-slate-300 px-3 text-sm font-bold text-slate-600 xl:hidden"
            onClick={() => setMobileDetail(false)}
            type="button"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to users
          </button>
          {!selectedId ? (
            <AsyncState
              emptyMessage="Select a user to review."
              state="empty"
            />
          ) : null}
          {selectedId && !detail && !detailError ? (
            <AsyncState state="loading" />
          ) : null}
          {detailError ? (
            <AsyncState
              errorMessage={detailError}
              onRetry={() => setReload((value) => value + 1)}
              state="error"
            />
          ) : null}
          {detail ? (
            <>
              <UserDetail
                onOpenPost={(postId) => openPost(postId, 'recent')}
                onSeeAllPosts={openAllPosts}
                user={detail}
              />
              {decisionError ? (
                <p
                  className="mx-5 mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700"
                  role="alert"
                >
                  {decisionError}
                </p>
              ) : null}
              <DecisionPanel
                helperText="Creator changes are audited and the member is notified."
                isSubmitting={submitting}
                onPrimary={() =>
                  setDecision({
                    nextValue: !detail.isContentCreator,
                  })
                }
                onReasonChange={setReason}
                primaryLabel={creatorButton}
                reason={reason}
                title="Creator decision"
              />
              <DecisionDialog
                confirmLabel={
                  decision?.nextValue
                    ? 'Confirm assignment'
                    : 'Confirm removal'
                }
                consequence={
                  decision?.nextValue
                    ? 'The member will be able to publish creator content.'
                    : 'The member will no longer have creator publishing access.'
                }
                isOpen={decision !== null}
                isSubmitting={submitting}
                onCancel={() => setDecision(null)}
                onConfirm={() => void confirmDecision()}
                title={
                  decision?.nextValue
                    ? 'Assign creator access?'
                    : 'Remove creator access?'
                }
                tone="primary"
              />
            </>
          ) : null}
        </div>
      </div>

      <AllPostsModal
        errorMessage={allPostsError}
        isOpen={allPostsOpen && !postDetailOpen}
        loading={allPostsLoading}
        onClose={() => setAllPostsOpen(false)}
        onOpenPost={(postId) => openPost(postId, 'all')}
        onRetry={detail ? () => void loadAllPosts(detail.id) : undefined}
        posts={allPosts}
      />
      <PostDetailModal
        errorMessage={postDetailError}
        isOpen={postDetailOpen}
        loading={postDetailLoading}
        onBack={postSource === 'all' ? closePostDetail : undefined}
        onClose={closePostDetail}
        onRetry={postDetailId ? () => void loadPost(postDetailId) : undefined}
        post={postDetail}
      />
    </section>
  );
}

function messageOf(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}
