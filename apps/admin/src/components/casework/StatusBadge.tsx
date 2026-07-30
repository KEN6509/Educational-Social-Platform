const labels: Record<string, string> = {
  active: 'Active',
  approved: 'Approved',
  dismissed: 'Dismissed',
  open: 'Pending Review',
  pending: 'Pending',
  rejected: 'Rejected',
  resolved: 'Resolved',
  reviewing: 'Reviewing',
  suspended: 'Suspended',
};

const tones: Record<string, string> = {
  active: 'border-emerald-200 bg-emerald-50 text-emerald-700',
  approved: 'border-emerald-200 bg-emerald-50 text-emerald-700',
  dismissed: 'border-slate-200 bg-slate-100 text-slate-600',
  open: 'border-amber-200 bg-amber-50 text-amber-800',
  pending: 'border-amber-200 bg-amber-50 text-amber-800',
  rejected: 'border-red-200 bg-red-50 text-red-700',
  resolved: 'border-emerald-200 bg-emerald-50 text-emerald-700',
  reviewing: 'border-cyan-200 bg-cyan-50 text-cyan-700',
  suspended: 'border-red-200 bg-red-50 text-red-700',
};

export function StatusBadge({ status }: { status: string }) {
  const key = status.toLowerCase();
  return (
    <span
      className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-bold ${
        tones[key] ?? 'border-slate-200 bg-slate-100 text-slate-600'
      }`}
    >
      {labels[key] ?? status}
    </span>
  );
}
