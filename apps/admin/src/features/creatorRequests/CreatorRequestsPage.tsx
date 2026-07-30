import { Search, UserRound } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';

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
  CreatorRequestDetailView,
  CreatorRequestSummaryView,
  PageResult,
} from '../../types/admin';
import { CreatorRequestDetail } from './CreatorRequestDetail';

type Status = 'pending' | 'approved' | 'rejected';

export function CreatorRequestsPage({
  api = adminApi,
}: {
  api?: AdminApi;
}) {
  const [status, setStatus] = useState<Status>('pending');
  const [searchDraft, setSearchDraft] = useState('');
  const [search, setSearch] = useState('');
  const [list, setList] =
    useState<PageResult<CreatorRequestSummaryView> | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<CreatorRequestDetailView | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [decision, setDecision] = useState<
    'approved' | 'rejected' | null
  >(null);
  const [submitting, setSubmitting] = useState(false);
  const [decisionError, setDecisionError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let active = true;
    setList(null);
    setError(null);
    void api
      .get<PageResult<CreatorRequestSummaryView>>('/admin/creator-requests', {
        page: 1,
        pageSize: 20,
        search,
        status,
      })
      .then((result) => {
        if (!active) return;
        setList(result);
        setSelectedId((current) =>
          result.items.some((item) => item.id === current)
            ? current
            : (result.items[0]?.id ?? null),
        );
      })
      .catch((nextError: unknown) => {
        if (active) setError(messageOf(nextError));
      });
    return () => {
      active = false;
    };
  }, [api, reload, search, status]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return;
    }
    let active = true;
    setDetail(null);
    void api
      .get<CreatorRequestDetailView>(
        `/admin/creator-requests/${selectedId}`,
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
  }, [api, reload, selectedId]);

  function submitSearch(event: FormEvent) {
    event.preventDefault();
    setSearch(searchDraft.trim());
  }

  async function confirmDecision() {
    if (!detail || !decision) return;
    setSubmitting(true);
    setDecisionError(null);
    try {
      await api.post(`/admin/creator-requests/${detail.id}/decision`, {
        decision,
        reason: reason.trim(),
      });
      setReason('');
      setDecision(null);
      setReload((value) => value + 1);
    } catch (nextError) {
      setDecision(null);
      setDecisionError(
        nextError instanceof AdminApiError && nextError.code === 'conflict'
          ? `${nextError.message} The queue has been refreshed.`
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
          <h1 className="text-3xl font-black tracking-tight">
            Creator Requests
          </h1>
          {status === 'pending' && list ? (
            <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-900">
              Pending {list.total}
            </span>
          ) : null}
        </div>
        <p className="mt-1 text-sm text-slate-500">
          Review and decide on creator applications.
        </p>
      </header>

      <div className="grid min-h-[calc(100vh-7rem)] xl:grid-cols-[26rem_minmax(0,1fr)]">
        <aside className="border-r border-slate-200">
          <form className="border-b border-slate-200 p-4" onSubmit={submitSearch}>
            <label className="relative block">
              <span className="sr-only">Search requests</span>
              <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-slate-400" />
              <input
                aria-label="Search requests"
                className="h-10 w-full rounded-lg border border-slate-300 pl-9 pr-3 text-sm outline-none focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
                onChange={(event) => setSearchDraft(event.target.value)}
                placeholder="Search requests…"
                type="search"
                value={searchDraft}
              />
            </label>
          </form>
          <CaseworkTabs
            activeId={status}
            items={[
              { id: 'pending', label: 'Pending' },
              { id: 'approved', label: 'Approved' },
              { id: 'rejected', label: 'Rejected' },
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
            <AsyncState
              emptyMessage={`No ${status} creator requests.`}
              state="empty"
            />
          ) : null}
          {list?.items.length ? (
            <CaseworkList
              items={list.items.map((item) => ({
                id: item.id,
                title: item.userName,
                subtitle:
                  item.reason || `${item.userEmail} requested creator access.`,
                meta: formatDate(item.createdAt),
                leading: item.avatarUrl ? (
                  <img
                    alt=""
                    className="h-11 w-11 rounded-full object-cover"
                    src={item.avatarUrl}
                  />
                ) : (
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-slate-100 text-slate-500">
                    <UserRound className="h-5 w-5" />
                  </span>
                ),
              }))}
              onSelect={setSelectedId}
              selectedId={selectedId}
            />
          ) : null}
        </aside>

        <div className="min-w-0">
          {!selectedId ? (
            <AsyncState
              emptyMessage="Select a creator request to review."
              state="empty"
            />
          ) : null}
          {selectedId && !detail && !error ? (
            <AsyncState state="loading" />
          ) : null}
          {detail ? (
            <>
              <CreatorRequestDetail request={detail} />
              {decisionError ? (
                <p
                  className="mx-5 mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700"
                  role="alert"
                >
                  {decisionError}
                </p>
              ) : null}
              {detail.status === 'pending' ? (
                <DecisionPanel
                  dangerLabel="Reject request"
                  isSubmitting={submitting}
                  onDanger={() => setDecision('rejected')}
                  onPrimary={() => setDecision('approved')}
                  onReasonChange={setReason}
                  primaryLabel="Approve creator"
                  reason={reason}
                />
              ) : null}
              <DecisionDialog
                confirmLabel={
                  decision === 'approved'
                    ? 'Confirm approval'
                    : 'Confirm rejection'
                }
                consequence={
                  decision === 'approved'
                    ? 'The requester will become a content creator and receive a notification.'
                    : 'The request will be rejected and the requester will receive your reason.'
                }
                isOpen={decision !== null}
                isSubmitting={submitting}
                onCancel={() => setDecision(null)}
                onConfirm={() => void confirmDecision()}
                title={
                  decision === 'approved'
                    ? 'Approve this creator request?'
                    : 'Reject this creator request?'
                }
                tone={decision === 'rejected' ? 'danger' : 'primary'}
              />
            </>
          ) : null}
        </div>
      </div>
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
    : 'Creator requests could not be loaded.';
}
