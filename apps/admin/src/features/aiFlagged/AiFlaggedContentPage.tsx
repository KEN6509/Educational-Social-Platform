import {
  ArrowLeft,
  Bot,
  FileText,
  FlaskConical,
  MessageSquare,
  ShieldAlert,
} from 'lucide-react';
import { useMemo, useState } from 'react';

import { AsyncState } from '../../components/casework/AsyncState';
import { CaseworkList } from '../../components/casework/CaseworkList';
import { CaseworkTabs } from '../../components/casework/CaseworkTabs';
import { DecisionDialog } from '../../components/casework/DecisionDialog';
import { DecisionPanel } from '../../components/casework/DecisionPanel';
import { StatusBadge } from '../../components/casework/StatusBadge';
import {
  decideAiFlaggedPreview,
  loadAiFlaggedPreview,
} from './aiFlaggedMockAdapter';
import type { AiFlaggedStatus } from './aiFlaggedTypes';

export function AiFlaggedContentPage() {
  const [rows, setRows] = useState(loadAiFlaggedPreview);
  const [status, setStatus] = useState<AiFlaggedStatus>('pending');
  const filtered = useMemo(
    () => rows.filter((item) => item.status === status),
    [rows, status],
  );
  const [selectedId, setSelectedId] = useState(
    () => rows.find((item) => item.status === 'pending')?.id ?? null,
  );
  const selected =
    filtered.find((item) => item.id === selectedId) ?? filtered[0] ?? null;
  const [reason, setReason] = useState('');
  const [decision, setDecision] = useState<
    'approved' | 'rejected' | null
  >(null);
  const [saved, setSaved] = useState(false);
  const [mobileDetail, setMobileDetail] = useState(false);

  function changeStatus(value: string) {
    const nextStatus = value as AiFlaggedStatus;
    setStatus(nextStatus);
    setSelectedId(
      rows.find((item) => item.status === nextStatus)?.id ?? null,
    );
    setSaved(false);
    setReason('');
  }

  function confirmDecision() {
    if (!selected || !decision) return;
    setRows((current) =>
      decideAiFlaggedPreview(current, selected.id, decision),
    );
    setDecision(null);
    setReason('');
    setSaved(true);
  }

  return (
    <section className="min-h-screen bg-white">
      <header className="border-b border-slate-200 px-5 py-6 lg:px-8">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-black tracking-tight">
            AI-Flagged Content
          </h1>
          <span className="inline-flex items-center gap-1.5 rounded-full bg-violet-50 px-3 py-1 text-xs font-bold text-violet-700">
            <FlaskConical className="h-3.5 w-3.5" aria-hidden="true" />
            Preview
          </span>
        </div>
        <p className="mt-1 text-sm text-slate-500">
          Preview the future AI-assisted moderation review workflow.
        </p>
      </header>

      <div
        className="flex items-center gap-3 border-b border-violet-200 bg-violet-50 px-5 py-3 text-sm font-bold text-violet-800 lg:px-8"
        role="note"
      >
        <Bot className="h-5 w-5" aria-hidden="true" />
        Preview data - Gemini integration is not connected.
      </div>

      <div className="grid min-h-[calc(100vh-10rem)] xl:grid-cols-[26rem_minmax(0,1fr)]">
        <aside
          className={`border-r border-slate-200 ${
            mobileDetail ? 'hidden xl:block' : 'block'
          }`}
        >
          <CaseworkTabs
            activeId={status}
            items={[
              {
                id: 'pending',
                label: 'Pending',
                count: rows.filter((item) => item.status === 'pending').length,
              },
              {
                id: 'approved',
                label: 'Approved',
                count: rows.filter((item) => item.status === 'approved').length,
              },
              {
                id: 'rejected',
                label: 'Rejected',
                count: rows.filter((item) => item.status === 'rejected').length,
              },
            ]}
            onChange={changeStatus}
          />
          {filtered.length === 0 ? (
            <AsyncState
              emptyMessage={`No ${status} preview cases.`}
              state="empty"
            />
          ) : (
            <CaseworkList
              items={filtered.map((item) => ({
                id: item.id,
                title: item.title || `${item.targetType === 'comment' ? 'Comment' : 'Post'} by ${item.authorName}`,
                subtitle: `${item.targetType === 'post' ? 'Post' : 'Comment'} · ${item.content}`,
                meta: `${Math.round(item.riskScore * 100)}%`,
                leading: (
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-violet-50 text-violet-700">
                    {item.targetType === 'post' ? (
                      <FileText className="h-5 w-5" />
                    ) : (
                      <MessageSquare className="h-5 w-5" />
                    )}
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
            Back to preview queue
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
                      {selected.authorName} · {selected.authorEmail}
                    </p>
                  </div>
                  <div className="rounded-xl border border-violet-200 bg-violet-50 px-4 py-3 text-right">
                    <p className="text-xs font-bold text-violet-600">
                      Preview risk score
                    </p>
                    <p className="mt-1 text-2xl font-black text-violet-800">
                      {selected.riskScore.toFixed(2)}
                    </p>
                  </div>
                </div>

                <section className="mt-6 rounded-xl border border-slate-200 bg-slate-50 p-5">
                  <h3 className="text-sm font-black uppercase tracking-wide text-slate-500">
                    Content
                  </h3>
                  <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
                    {selected.content}
                  </p>
                </section>

                <section className="mt-5 rounded-xl border border-violet-200 bg-violet-50/50 p-5">
                  <div className="flex items-center gap-2 text-violet-800">
                    <ShieldAlert className="h-5 w-5" aria-hidden="true" />
                    <h3 className="font-black">Preview evidence</h3>
                  </div>
                  <ul className="mt-3 space-y-2 pl-5 text-sm leading-6 text-slate-600">
                    {selected.evidence.map((item) => (
                      <li className="list-disc" key={item}>
                        {item}
                      </li>
                    ))}
                  </ul>
                </section>
              </div>

              {saved ? (
                <p
                  className="mx-5 mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-700"
                  role="status"
                >
                  Preview decision saved locally.
                </p>
              ) : null}
              {selected.status === 'pending' ? (
                <DecisionPanel
                  dangerLabel="Reject content"
                  helperText="Preview only: this decision stays in component memory and is not sent anywhere."
                  isSubmitting={false}
                  onDanger={() => setDecision('rejected')}
                  onPrimary={() => setDecision('approved')}
                  onReasonChange={setReason}
                  primaryLabel="Approve content"
                  reason={reason}
                  title="Preview decision"
                />
              ) : null}
              <DecisionDialog
                confirmLabel={
                  decision === 'approved'
                    ? 'Confirm approval'
                    : 'Confirm rejection'
                }
                consequence="This changes only the temporary preview state. No production content or database row will be modified."
                isOpen={decision !== null}
                isSubmitting={false}
                onCancel={() => setDecision(null)}
                onConfirm={confirmDecision}
                title={
                  decision === 'approved'
                    ? 'Approve preview content?'
                    : 'Reject preview content?'
                }
                tone={decision === 'rejected' ? 'danger' : 'primary'}
              />
            </>
          ) : (
            <AsyncState
              emptyMessage="Select a preview case to inspect."
              state="empty"
            />
          )}
        </div>
      </div>
    </section>
  );
}
