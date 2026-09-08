import { AlertCircle, Inbox, Loader2, RotateCcw } from 'lucide-react';

type Props = {
  state: 'loading' | 'empty' | 'error';
  emptyMessage?: string;
  errorMessage?: string;
  onRetry?: () => void;
};

export function AsyncState({
  state,
  emptyMessage = 'No casework matches these filters.',
  errorMessage = 'Casework could not be loaded.',
  onRetry,
}: Props) {
  const isLoading = state === 'loading';
  const Icon = isLoading ? Loader2 : state === 'empty' ? Inbox : AlertCircle;
  const message = isLoading
    ? 'Loading casework…'
    : state === 'empty'
      ? emptyMessage
      : errorMessage;

  return (
    <section
      className="grid min-h-64 place-items-center px-6 py-12 text-center"
      role={state === 'error' ? 'alert' : 'status'}
    >
      <div className="max-w-xs">
        <span className="mx-auto grid h-11 w-11 place-items-center rounded-xl bg-slate-100 text-slate-500">
          <Icon
            aria-hidden="true"
            className={`h-5 w-5 ${isLoading ? 'animate-spin' : ''}`}
          />
        </span>
        <p className="mt-4 text-sm font-semibold text-slate-600">{message}</p>
        {state === 'error' && onRetry ? (
          <button
            className="mt-4 inline-flex h-10 items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 text-sm font-bold text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-4 focus:ring-cyan-100"
            onClick={onRetry}
            type="button"
          >
            <RotateCcw className="h-4 w-4" aria-hidden="true" />
            Try again
          </button>
        ) : null}
      </div>
    </section>
  );
}
