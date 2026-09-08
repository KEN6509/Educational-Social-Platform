import { AlertTriangle, Loader2, X } from 'lucide-react';
import { useEffect } from 'react';

type Props = {
  isOpen: boolean;
  title: string;
  consequence: string;
  confirmLabel: string;
  isSubmitting: boolean;
  onCancel: () => void;
  onConfirm: () => void;
  tone?: 'primary' | 'danger';
};

export function DecisionDialog({
  isOpen,
  title,
  consequence,
  confirmLabel,
  isSubmitting,
  onCancel,
  onConfirm,
  tone = 'primary',
}: Props) {
  useEffect(() => {
    if (!isOpen) return;
    const listener = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !isSubmitting) onCancel();
    };
    document.addEventListener('keydown', listener);
    return () => document.removeEventListener('keydown', listener);
  }, [isOpen, isSubmitting, onCancel]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center bg-slate-950/55 px-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !isSubmitting) onCancel();
      }}
      role="presentation"
    >
      <section
        aria-describedby="decision-consequence"
        aria-labelledby="decision-title"
        aria-modal="true"
        className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-2xl"
        role="dialog"
      >
        <div className="flex items-start justify-between gap-4">
          <span className="grid h-11 w-11 place-items-center rounded-xl bg-amber-50 text-amber-700 ring-1 ring-amber-200">
            <AlertTriangle className="h-5 w-5" aria-hidden="true" />
          </span>
          <button
            aria-label="Close confirmation"
            className="grid h-9 w-9 place-items-center rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-700 disabled:opacity-40"
            disabled={isSubmitting}
            onClick={onCancel}
            type="button"
          >
            <X className="h-5 w-5" aria-hidden="true" />
          </button>
        </div>
        <h2 className="mt-5 text-xl font-black text-cyanZone-ink" id="decision-title">
          {title}
        </h2>
        <p className="mt-2 text-sm leading-6 text-slate-600" id="decision-consequence">
          {consequence}
        </p>
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          <button
            className="h-11 rounded-lg border border-slate-300 bg-white px-4 text-sm font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-45"
            disabled={isSubmitting}
            onClick={onCancel}
            type="button"
          >
            Cancel
          </button>
          <button
            className={`inline-flex h-11 items-center justify-center gap-2 rounded-lg px-4 text-sm font-bold text-white disabled:opacity-60 ${
              tone === 'danger' ? 'bg-red-600 hover:bg-red-700' : 'bg-cyanZone-cyan hover:bg-cyan-700'
            }`}
            disabled={isSubmitting}
            onClick={onConfirm}
            type="button"
          >
            {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            {isSubmitting ? 'Confirming…' : confirmLabel}
          </button>
        </div>
      </section>
    </div>
  );
}
