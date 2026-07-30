import {
  Eye,
  EyeOff,
  FileText,
  Flag,
  Mail,
  MessageSquare,
  UserRound,
} from 'lucide-react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { ReportCaseDetailView } from '../../types/admin';

export function ReportCaseDetail({
  reportCase,
}: {
  reportCase: ReportCaseDetailView;
}) {
  const visible = !['rejected', 'removed'].includes(
    reportCase.moderationStatus ?? '',
  );

  return (
    <div className="p-5 lg:p-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-red-50 text-red-600">
              {reportCase.targetType === 'post' ? (
                <FileText className="h-5 w-5" aria-hidden="true" />
              ) : (
                <MessageSquare className="h-5 w-5" aria-hidden="true" />
              )}
            </span>
            <div>
              <p className="text-xs font-bold uppercase tracking-wide text-slate-400">
                {reportCase.targetType} case
              </p>
              <h2 className="text-2xl font-black">
                {reportCase.targetTitle ||
                  `Reported ${reportCase.targetType}`}
              </h2>
            </div>
            <StatusBadge status={reportCase.status} />
          </div>
          <div className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-slate-500">
            <span className="inline-flex items-center gap-1.5">
              <UserRound className="h-4 w-4" aria-hidden="true" />
              {reportCase.ownerName}
            </span>
            {reportCase.ownerEmail ? (
              <span className="inline-flex items-center gap-1.5">
                <Mail className="h-4 w-4" aria-hidden="true" />
                {reportCase.ownerEmail}
              </span>
            ) : null}
          </div>
        </div>
        <span
          className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-bold ${
            visible
              ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
              : 'border-slate-200 bg-slate-100 text-slate-600'
          }`}
        >
          {visible ? (
            <Eye className="h-4 w-4" aria-hidden="true" />
          ) : (
            <EyeOff className="h-4 w-4" aria-hidden="true" />
          )}
          {visible ? 'Currently visible' : 'Currently hidden'}
        </span>
      </div>

      <section className="mt-6 rounded-xl border border-slate-200 bg-slate-50 p-5">
        <h3 className="text-sm font-black uppercase tracking-wide text-slate-500">
          Reported content
        </h3>
        <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
          {reportCase.content || reportCase.targetExcerpt}
        </p>
      </section>

      <div className="mt-6 grid gap-5 lg:grid-cols-2">
        <section className="rounded-xl border border-red-200 bg-red-50/50 p-5">
          <div className="flex items-center gap-2">
            <Flag className="h-5 w-5 text-red-600" aria-hidden="true" />
            <h3 className="font-black">
              {reportCase.uniqueReporters} unique reports
            </h3>
          </div>
          <p className="mt-1 text-xs text-slate-500">
            This is one grouped case for a single content target.
          </p>
          <div className="mt-4 space-y-2">
            {reportCase.reasonCounts.map((item) => (
              <div
                className="flex items-center justify-between rounded-lg bg-white px-3 py-2 text-sm"
                key={item.reason}
              >
                <span className="font-semibold text-slate-700">
                  {item.reason}
                </span>
                <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-black text-red-700">
                  {item.count}
                </span>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-xl border border-slate-200 p-5">
          <h3 className="font-black">Reporter context</h3>
          <div className="mt-3 space-y-3">
            {reportCase.reports.slice(0, 5).map((report) => (
              <article key={report.id}>
                <p className="text-sm leading-6 text-slate-600">
                  {report.description || 'No additional description provided.'}
                </p>
                <time
                  className="mt-1 block text-xs text-slate-400"
                  dateTime={report.createdAt}
                >
                  {formatDateTime(report.createdAt)}
                </time>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('en-MY', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
