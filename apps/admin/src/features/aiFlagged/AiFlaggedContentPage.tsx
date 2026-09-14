import {
  ArrowLeft,
  FileText,
  Image as ImageIcon,
  MessageSquare,
  ShieldAlert,
} from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';

import { AsyncState } from '../../components/casework/AsyncState';
import { CaseworkList } from '../../components/casework/CaseworkList';
import { CaseworkTabs } from '../../components/casework/CaseworkTabs';
import { DecisionDialog } from '../../components/casework/DecisionDialog';
import { DecisionPanel } from '../../components/casework/DecisionPanel';
import { StatusBadge } from '../../components/casework/StatusBadge';
import { AdminApiError } from '../../lib/adminApi';
import {
  decideAiFlaggedCase,
  loadAiFlaggedCases,
} from './aiFlaggedApi';
import { ModerationImageGallery } from './ModerationImageGallery';
import type { AiFlaggedCase, AiFlaggedStatus } from './aiFlaggedTypes';

export function AiFlaggedContentPage() {
  type QueueState = {
    rows: AiFlaggedCase[];
    loadState: 'loading' | 'empty' | 'error' | 'ready';
    errorMessage: string;
    refreshError: string | null;
  };
  const initialQueue: QueueState = {
    rows: [],
    loadState: 'loading',
    errorMessage: 'Casework could not be loaded.',
    refreshError: null,
  };
  const [queues, setQueues] = useState<Record<AiFlaggedStatus, QueueState>>({
    pending: initialQueue,
    approved: { ...initialQueue },
    rejected: { ...initialQueue },
  });
  const [status, setStatus] = useState<AiFlaggedStatus>('pending');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [decision, setDecision] = useState<'approved' | 'rejected' | null>(null);
  const [saved, setSaved] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [mobileDetail, setMobileDetail] = useState(false);
  const requestGeneration = useRef(0);
  const activeQueue = queues[status];
  const rows = activeQueue.rows;

  async function load(statusToLoad = status) {
    const generation = ++requestGeneration.current;
    setQueues((current) => ({
      ...current,
      [statusToLoad]: {
        ...current[statusToLoad],
        loadState: current[statusToLoad].rows.length > 0 ? 'ready' : 'loading',
        errorMessage: 'Casework could not be loaded.',
        refreshError: null,
      },
    }));
    try {
      const page = await loadAiFlaggedCases(statusToLoad);
      if (generation !== requestGeneration.current) return;
      setQueues((current) => ({
        ...current,
        [statusToLoad]: {
          rows: page.items,
          loadState: page.items.length === 0 ? 'empty' : 'ready',
          errorMessage: 'Casework could not be loaded.',
          refreshError: null,
        },
      }));
      setSelectedId((current) =>
        page.items.some((item) => item.id === current)
          ? current
          : page.items[0]?.id ?? null,
      );
    } catch (error) {
      if (generation !== requestGeneration.current) return;
      const existingRows = queues[statusToLoad].rows;
      setQueues((current) => ({
        ...current,
        [statusToLoad]: {
          ...current[statusToLoad],
          loadState: existingRows.length > 0 ? 'ready' : 'error',
          errorMessage: error instanceof AdminApiError
            ? error.message
            : 'Casework could not be loaded.',
          refreshError: existingRows.length > 0
            ? error instanceof AdminApiError
              ? error.message
              : 'Casework could not be refreshed.'
            : null,
        },
      }));
      if (existingRows.length === 0) {
        setSelectedId(null);
      }
    }
  }

  useEffect(() => {
    void load(status);
  }, [status]);

  const selected = useMemo(
    () => rows.find((item) => item.id === selectedId) ?? rows[0] ?? null,
    [rows, selectedId],
  );

  function changeStatus(value: string) {
    setStatus(value as AiFlaggedStatus);
    setSaved(false);
    setReason('');
    setMobileDetail(false);
  }

  async function confirmDecision() {
    if (!selected || !decision) return;
    setIsSubmitting(true);
    try {
      await decideAiFlaggedCase(selected.id, decision, reason.trim());
      setDecision(null);
      setReason('');
      setSaved(true);
      await load(status);
    } catch (error) {
      setQueues((current) => ({
        ...current,
        [status]: {
          ...current[status],
          errorMessage: error instanceof AdminApiError
            ? error.message
            : 'The moderation decision could not be saved.',
          refreshError: error instanceof AdminApiError
            ? error.message
            : 'The moderation decision could not be saved.',
        },
      }));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="min-h-screen bg-white">
      <header className="border-b border-slate-200 px-5 py-6 lg:px-8">
        <h1 className="text-3xl font-black tracking-tight">AI-Flagged Content</h1>
        <p className="mt-1 text-sm text-slate-500">
          Review content identified by Gemini moderation.
        </p>
      </header>
      {activeQueue.refreshError ? (
        <p
          className="m-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-bold text-amber-800"
          role="alert"
        >
          {activeQueue.refreshError}
        </p>
      ) : null}

      <div className="grid min-h-[calc(100vh-7rem)] xl:grid-cols-[26rem_minmax(0,1fr)]">
        <aside className={`border-r border-slate-200 ${mobileDetail ? 'hidden xl:block' : 'block'}`}>
          <CaseworkTabs
            activeId={status}
            items={[
              { id: 'pending', label: 'Pending' },
              { id: 'approved', label: 'Approved' },
              { id: 'rejected', label: 'Rejected' },
            ]}
            onChange={changeStatus}
          />
          {(activeQueue.loadState === 'loading' && rows.length === 0) || (activeQueue.loadState === 'error' && rows.length === 0) || (activeQueue.loadState === 'empty' && rows.length === 0) ? (
            <AsyncState
              emptyMessage={`No ${status} cases.`}
              errorMessage={activeQueue.errorMessage}
              onRetry={() => void load(status)}
              state={activeQueue.loadState}
            />
          ) : (
            <CaseworkList
              items={rows.map((item) => ({
                id: item.id,
                title: item.title || `${item.targetType === 'comment' ? 'Comment' : 'Post'} by ${item.authorName}`,
                subtitle: `${item.targetType === 'post' ? 'Post' : 'Comment'} · ${item.content}`,
                meta: `${item.riskScore.toFixed(0)}%`,
                leading: (
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-violet-50 text-violet-700">
                    {item.targetType === 'post' ? <FileText className="h-5 w-5" /> : <MessageSquare className="h-5 w-5" />}
                  </span>
                ),
              }))}
              onSelect={(id) => {
                setSelectedId(id);
                setSaved(false);
                setMobileDetail(true);
              }}
              selectedId={selected?.id ?? null}
            />
          )}
        </aside>

        <div className={`min-w-0 ${mobileDetail ? 'block' : 'hidden xl:block'}`}>
          <button
            className="m-4 inline-flex h-10 items-center gap-2 rounded-lg border border-slate-300 px-3 text-sm font-bold text-slate-600 xl:hidden"
            onClick={() => setMobileDetail(false)}
            type="button"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to queue
          </button>
          {selected ? (
            <>
              <div className="p-5 lg:p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <div className="flex flex-wrap items-center gap-3">
                      <span className="text-xs font-black uppercase tracking-wider text-violet-600">
                        {selected.targetType === 'post' ? 'Post' : 'Comment'}
                      </span>
                      <StatusBadge status={selected.status} />
                    </div>
                    <h2 className="mt-2 text-2xl font-black">
                      {selected.title || `Comment by ${selected.authorName}`}
                    </h2>
                    <p className="mt-1 text-sm text-slate-500">
                      {selected.authorName} · {selected.authorEmail} · {selected.model}
                    </p>
                  </div>
                  <div className="rounded-xl border border-violet-200 bg-violet-50 px-4 py-3 text-right">
                    <p className="text-xs font-bold text-violet-600">Risk score</p>
                    <p className="mt-1 text-2xl font-black text-violet-800">
                      {selected.riskScore.toFixed(0)}
                    </p>
                  </div>
                </div>

                <section className="mt-6 rounded-xl border border-slate-200 bg-slate-50 p-5">
                  <h3 className="text-sm font-black uppercase tracking-wide text-slate-500">Content</h3>
                  <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">{selected.content}</p>
                </section>

                {selected.targetType === 'post' ? (
                  <section className="mt-5 rounded-xl border border-slate-200 p-5">
                    <div className="flex items-center gap-2 text-slate-700">
                      <ImageIcon className="h-5 w-5" aria-hidden="true" />
                      <h3 className="font-black">Attached images</h3>
                    </div>
                    <ModerationImageGallery imageUrls={selected.imageUrls} />
                  </section>
                ) : null}

                <section className="mt-5 rounded-xl border border-violet-200 bg-violet-50/50 p-5">
                  <div className="flex items-center gap-2 text-violet-800">
                    <ShieldAlert className="h-5 w-5" aria-hidden="true" />
                    <h3 className="font-black">Flag evidence</h3>
                  </div>
                  <ul className="mt-3 space-y-2 pl-5 text-sm leading-6 text-slate-600">
                    {selected.evidence.map((item) => <li className="list-disc" key={item}>{item}</li>)}
                  </ul>
                  <p className="mt-4 text-sm text-slate-600">{selected.userReason}</p>
                </section>
              </div>

              {saved ? <p className="mx-5 mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-700" role="status">Decision saved.</p> : null}
              {selected.status === 'pending' ? (
                <DecisionPanel
                  dangerLabel="Reject content"
                  dangerRequiresReason
                  helperText="Approval publishes eligible uncertain content. Rejection requires a clear moderation reason."
                  isSubmitting={isSubmitting}
                  onDanger={() => setDecision('rejected')}
                  onPrimary={() => setDecision('approved')}
                  onReasonChange={setReason}
                  primaryLabel="Approve content"
                  primaryRequiresReason={false}
                  reason={reason}
                  title="Moderation decision"
                />
              ) : null}
              <DecisionDialog
                confirmLabel={decision === 'approved' ? 'Confirm approval' : 'Confirm rejection'}
                consequence="This updates the content moderation status in the review queue."
                isOpen={decision !== null}
                isSubmitting={isSubmitting}
                onCancel={() => setDecision(null)}
                onConfirm={() => void confirmDecision()}
                title={decision === 'approved' ? 'Approve content?' : 'Reject content?'}
                tone={decision === 'rejected' ? 'danger' : 'primary'}
              />
            </>
          ) : (
            <AsyncState emptyMessage="Select a case to inspect." state="empty" />
          )}
        </div>
      </div>
    </section>
  );
}
