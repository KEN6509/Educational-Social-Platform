import { ArrowLeft, FileWarning, Search } from 'lucide-react';
import { useEffect, useRef, useState, type FormEvent } from 'react';

import { AsyncState } from '../../components/casework/AsyncState';
import { CaseworkList } from '../../components/casework/CaseworkList';
import { CaseworkTabs } from '../../components/casework/CaseworkTabs';
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
  ReportCaseDetailView,
  ReportCaseSummaryView,
} from '../../types/admin';
import { ReportCaseDetail } from './ReportCaseDetail';
import { PostDetailModal } from '../users/PostDetailModal';

type Status = 'pending_review' | 'resolved' | 'dismissed';

export function ReportsPage({ api = adminApi }: { api?: AdminApi }) {
  const [status, setStatus] = useState<Status>('pending_review');
  const [searchDraft, setSearchDraft] = useState('');
  const [search, setSearch] = useState('');
  const [list, setList] =
    useState<PageResult<ReportCaseSummaryView> | null>(null);
  const [selected, setSelected] = useState<{
    type: 'post' | 'comment';
    id: string;
  } | null>(null);
  const [detail, setDetail] = useState<ReportCaseDetailView | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [decision, setDecision] = useState<'retain' | 'remove' | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [decisionError, setDecisionError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);
  const [mobileDetail, setMobileDetail] = useState(false);
  const [postDetailOpen, setPostDetailOpen] = useState(false);
  const [postDetail, setPostDetail] = useState<AdminPostDetailView | null>(null);
  const [postDetailLoading, setPostDetailLoading] = useState(false);
  const [postDetailError, setPostDetailError] = useState<string | null>(null);
  const [postDetailId, setPostDetailId] = useState<string | null>(null);
  const postTriggerRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    let active = true;
    setList(null);
    setError(null);
    void api
      .get<PageResult<ReportCaseSummaryView>>('/admin/report-cases', {
        page: 1,
        pageSize: 20,
        search,
        status,
      })
      .then((result) => {
        if (!active) return;
        setList(result);
        setSelected((current) => {
          const retained = result.items.find(
            (item) =>
              item.targetId === current?.id &&
              item.targetType === current.type,
          );
          const next = retained ?? result.items[0];
          return next
            ? { type: next.targetType, id: next.targetId }
            : null;
        });
      })
      .catch((nextError: unknown) => {
        if (active) setError(messageOf(nextError));
      });
    return () => {
      active = false;
    };
  }, [api, reload, search, status]);

  useEffect(() => {
    if (!selected) {
      setDetail(null);
      return;
    }
    let active = true;
    setDetail(null);
    void api
      .get<ReportCaseDetailView>(
        `/admin/report-cases/${selected.type}/${selected.id}`,
      )
      .then((result) => {
        if (active) setDetail(result);
      })
      .catch((nextError: unknown) => {
        if (active) setError(messageOf(nextError));
      });
    return () => {
      active = false;
    };
  }, [api, reload, selected]);

  function submitSearch(event: FormEvent) {
    event.preventDefault();
    setSearch(searchDraft.trim());
  }

  async function loadPost(postId: string) {
    setPostDetailLoading(true);
    setPostDetailError(null);
    try {
      setPostDetail(
        await api.get<AdminPostDetailView>(`/admin/posts/${postId}`),
      );
    } catch (nextError) {
      setPostDetailError(
        nextError instanceof Error
          ? nextError.message
          : 'Post details could not be loaded.',
      );
    } finally {
      setPostDetailLoading(false);
    }
  }

  function openReportedPost() {
    if (!detail || detail.targetType !== 'post') return;
    postTriggerRef.current = document.activeElement as HTMLElement | null;
    setPostDetailId(detail.targetId);
    setPostDetail(null);
    setPostDetailOpen(true);
    void loadPost(detail.targetId);
  }

  function closePostDetail() {
    setPostDetailOpen(false);
    setPostDetail(null);
    setPostDetailError(null);
    setPostDetailId(null);
    window.setTimeout(() => postTriggerRef.current?.focus(), 0);
  }

  async function confirmDecision() {
    if (!detail || !decision) return;
    setSubmitting(true);
    setDecisionError(null);
    try {
      await api.post(
        `/admin/report-cases/${detail.targetType}/${detail.targetId}/decision`,
        { decision, reason: reason.trim() },
      );
      setDecision(null);
      setReason('');
      setReload((value) => value + 1);
    } catch (nextError) {
      setDecision(null);
      setDecisionError(
        nextError instanceof AdminApiError && nextError.code === 'conflict'
          ? `${nextError.message} The grouped case has been refreshed.`
          : messageOf(nextError),
      );
      if (
        nextError instanceof AdminApiError &&
        nextError.code === 'conflict'
      ) {
        setReload((value) => value + 1);
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="min-h-screen bg-white">
      <header className="border-b border-slate-200 px-5 py-6 lg:px-8">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-black tracking-tight">Reports</h1>
          {list ? (
            <span className="rounded-full bg-red-50 px-3 py-1 text-xs font-bold text-red-700">
              {list.total} case{list.total === 1 ? '' : 's'}
            </span>
          ) : null}
        </div>
        <p className="mt-1 text-sm text-slate-500">
          Review grouped content cases reported by the community.
        </p>
      </header>

      <div className="grid min-h-[calc(100vh-7rem)] xl:grid-cols-[26rem_minmax(0,1fr)]">
        <aside
          className={`border-r border-slate-200 ${
            mobileDetail ? 'hidden xl:block' : 'block'
          }`}
        >
          <form className="border-b border-slate-200 p-4" onSubmit={submitSearch}>
            <label className="relative block">
              <span className="sr-only">Search report cases</span>
              <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-slate-400" />
              <input
                aria-label="Search report cases"
                className="h-10 w-full rounded-lg border border-slate-300 pl-9 pr-3 text-sm outline-none focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
                onChange={(event) => setSearchDraft(event.target.value)}
                placeholder="Search cases…"
                type="search"
                value={searchDraft}
              />
            </label>
          </form>
          <CaseworkTabs
            activeId={status}
            items={[
              { id: 'pending_review', label: 'Pending Review' },
              { id: 'resolved', label: 'Resolved' },
              { id: 'dismissed', label: 'Dismissed' },
            ]}
            onChange={(value) => setStatus(value as Status)}
          />
          {!list && !error ? <AsyncState state="loading" /> : null}
          {error ? (
            <AsyncState
              errorMessage={error}
              onRetry={() => setReload((value) => value + 1)}
              state="error"
            />
          ) : null}
          {list?.items.length === 0 ? (
            <AsyncState emptyMessage="No grouped cases in this queue." state="empty" />
          ) : null}
          {list?.items.length ? (
            <CaseworkList
              items={list.items.map((item) => ({
                id: `${item.targetType}:${item.targetId}`,
                title:
                  item.targetTitle ||
                  `Reported ${item.targetType}`,
                subtitle: item.targetExcerpt,
                supportingText: `${item.totalReports} reports · ${item.uniqueReporters} reporters`,
                meta: formatDate(item.latestReportedAt),
                leading: (
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-red-50 text-red-600">
                    <FileWarning className="h-5 w-5" />
                  </span>
                ),
              }))}
              onSelect={(value) => {
                const [type, id] = value.split(':');
                setSelected({
                  type: type as 'post' | 'comment',
                  id,
                });
                setMobileDetail(true);
              }}
              selectedId={
                selected ? `${selected.type}:${selected.id}` : null
              }
            />
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
            Back to cases
          </button>
          {!selected ? (
            <AsyncState emptyMessage="Select a grouped report case." state="empty" />
          ) : null}
          {selected && !detail && !error ? <AsyncState state="loading" /> : null}
          {detail ? (
            <>
              <ReportCaseDetail
                onViewPost={
                  detail.targetType === 'post' ? openReportedPost : undefined
                }
                reportCase={detail}
              />
              {decisionError ? (
                <p
                  className="mx-5 mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700"
                  role="alert"
                >
                  {decisionError}
                </p>
              ) : null}
              {detail.status === 'pending_review' ? (
                <DecisionPanel
                  dangerLabel="Remove content"
                  dangerRequiresReason
                  helperText="Retaining keeps the content visible without notifying the author. Removing hides it, records the reason, and notifies the author."
                  isSubmitting={submitting}
                  onDanger={() => setDecision('remove')}
                  onPrimary={() => setDecision('retain')}
                  onReasonChange={setReason}
                  primaryLabel="Retain content"
                  primaryRequiresReason={false}
                  reason={reason}
                />
              ) : null}
              <DecisionDialog
                confirmLabel={
                  decision === 'remove'
                    ? 'Confirm removal'
                    : 'Confirm retention'
                }
                consequence={
                  decision === 'remove'
                    ? 'The content will be hidden and all reports in this grouped case will be resolved.'
                    : 'The content will remain visible and this grouped case will be dismissed.'
                }
                isOpen={decision !== null}
                isSubmitting={submitting}
                onCancel={() => setDecision(null)}
                onConfirm={() => void confirmDecision()}
                title={
                  decision === 'remove'
                    ? 'Remove this content?'
                    : 'Retain this content?'
                }
                tone={decision === 'remove' ? 'danger' : 'primary'}
              />
            </>
          ) : null}
        </div>
      </div>
      <PostDetailModal
        errorMessage={postDetailError}
        isOpen={postDetailOpen}
        loading={postDetailLoading}
        onClose={closePostDetail}
        onRetry={postDetailId ? () => void loadPost(postDetailId) : undefined}
        post={postDetail}
      />
    </section>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}

function messageOf(error: unknown) {
  return error instanceof Error
    ? error.message
    : 'Report cases could not be loaded.';
}
