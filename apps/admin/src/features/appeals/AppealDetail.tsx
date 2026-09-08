import {
  CalendarDays,
  FileWarning,
  Mail,
  MessageSquareQuote,
  ShieldAlert,
  UserRound,
} from 'lucide-react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { AppealDetailView } from '../../types/admin';

export function AppealDetail({ appeal }: { appeal: AppealDetailView }) {
  return (
    <div className="p-5 lg:p-6">
      <div className="flex flex-wrap items-start gap-4">
        <span className="grid h-14 w-14 place-items-center rounded-full bg-cyan-50 text-cyan-700">
          <UserRound className="h-6 w-6" aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-2xl font-black">{appeal.postTitle}</h2>
            <StatusBadge status={appeal.status} />
          </div>
          <p className="mt-1 text-sm font-bold text-slate-700">
            Appeal by {appeal.userName}
          </p>
          <div className="mt-2 flex flex-wrap gap-x-5 gap-y-2 text-sm text-slate-500">
            <span className="inline-flex items-center gap-1.5">
              <Mail className="h-4 w-4" aria-hidden="true" />
              {appeal.userEmail}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CalendarDays className="h-4 w-4" aria-hidden="true" />
              Submitted {formatDateTime(appeal.createdAt)}
            </span>
          </div>
        </div>
      </div>

      <div className="mt-6 grid gap-5 lg:grid-cols-2">
        <section className="rounded-xl border border-red-200 bg-red-50/50 p-5">
          <div className="flex items-center gap-2 text-red-800">
            <FileWarning className="h-5 w-5" aria-hidden="true" />
            <h3 className="font-black">Rejected content</h3>
          </div>
          {appeal.postContent ? (
            <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
              {appeal.postContent}
            </p>
          ) : (
            <p className="mt-3 rounded-lg bg-white px-3 py-4 text-sm text-slate-500">
              The original content is no longer available.
            </p>
          )}
        </section>

        <section className="rounded-xl border border-slate-200 bg-slate-50 p-5">
          <div className="flex items-center gap-2 text-slate-700">
            <ShieldAlert className="h-5 w-5" aria-hidden="true" />
            <h3 className="font-black">Original moderation evidence</h3>
          </div>
          <p className="mt-3 text-sm leading-7 text-slate-600">
            {appeal.originalModerationReason ||
              'No original moderation reason was recorded.'}
          </p>
          {appeal.originalReviewedAt ? (
            <time
              className="mt-3 block text-xs text-slate-400"
              dateTime={appeal.originalReviewedAt}
            >
              Reviewed {formatDateTime(appeal.originalReviewedAt)}
            </time>
          ) : null}
        </section>
      </div>

      <section className="mt-5 rounded-xl border border-cyan-200 bg-cyan-50/60 p-5">
        <div className="flex items-center gap-2 text-cyan-900">
          <MessageSquareQuote className="h-5 w-5" aria-hidden="true" />
          <h3 className="font-black">Member appeal</h3>
        </div>
        <p className="mt-3 text-sm leading-7 text-cyan-950/80">
          {appeal.reason}
        </p>
      </section>

      {appeal.status !== 'pending' ? (
        <section className="mt-5 rounded-xl border border-slate-200 p-5">
          <h3 className="font-black">Recorded decision</h3>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            {appeal.adminNote || 'No administrator note was recorded.'}
          </p>
          <p className="mt-2 text-xs text-slate-500">
            {appeal.reviewedBy ?? 'Administrator'}
            {appeal.reviewedAt
              ? ` · ${formatDateTime(appeal.reviewedAt)}`
              : ''}
          </p>
        </section>
      ) : null}
    </div>
  );
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('en-MY', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
