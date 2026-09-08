import {
  Eye,
  EyeOff,
  FileText,
  Mail,
  MessageSquare,
  UserRound,
} from 'lucide-react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { ReportCaseDetailView } from '../../types/admin';
import { ReportReasonChart } from './ReportReasonChart';

export function ReportCaseDetail({
  reportCase,
  onViewPost,
}: {
  reportCase: ReportCaseDetailView;
  onViewPost?: () => void;
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
                {reportCase.targetTitle || `Reported ${reportCase.targetType}`}
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
        {reportCase.targetType === 'post' ? (
          <button
            className="mt-3 text-sm font-extrabold text-cyan-700 transition hover:text-cyan-900 focus:outline-none focus:ring-4 focus:ring-cyan-100"
            onClick={onViewPost}
            type="button"
          >
            View Post &gt;
          </button>
        ) : (
          <p className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
            {reportCase.content || reportCase.targetExcerpt}
          </p>
        )}
      </section>

      <ReportReasonChart
        reasonCounts={reportCase.reasonCounts}
        totalReports={reportCase.totalReports}
        uniqueReporters={reportCase.uniqueReporters}
      />
    </div>
  );
}
