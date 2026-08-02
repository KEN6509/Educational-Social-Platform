import { Check, X } from 'lucide-react';
import { useRef, useState } from 'react';

type Props = {
  reason: string;
  onReasonChange: (value: string) => void;
  primaryLabel: string;
  dangerLabel?: string;
  isSubmitting: boolean;
  onPrimary: () => void;
  onDanger?: () => void;
  title?: string;
  helperText?: string;
  dangerDisabled?: boolean;
  primaryRequiresReason?: boolean;
  dangerRequiresReason?: boolean;
};

export function DecisionPanel({
  reason,
  onReasonChange,
  primaryLabel,
  dangerLabel,
  isSubmitting,
  onPrimary,
  onDanger,
  title = 'Your decision',
  helperText = 'Provide a clear reason. This decision will be recorded.',
  dangerDisabled = false,
  primaryRequiresReason = true,
  dangerRequiresReason = true,
}: Props) {
  const [validationError, setValidationError] = useState<string | null>(null);
  const reasonRef = useRef<HTMLTextAreaElement>(null);
  const reasonLength = reason.trim().length;

  function runAction(
    label: string,
    requiresReason: boolean,
    action: () => void,
  ) {
    const missingRequiredReason = requiresReason && reasonLength === 0;
    const invalidSuppliedReason =
      reasonLength > 0 && (reasonLength < 10 || reasonLength > 500);
    if (missingRequiredReason || invalidSuppliedReason) {
      setValidationError(
        `Enter a reason between 10 and 500 characters before choosing "${label}".`,
      );
      reasonRef.current?.focus();
      return;
    }
    setValidationError(null);
    action();
  }

  const requirementLabel =
    primaryRequiresReason && (!dangerLabel || dangerRequiresReason)
      ? '(required)'
      : !primaryRequiresReason && dangerLabel && dangerRequiresReason
        ? `(required for ${dangerLabel})`
        : primaryRequiresReason && dangerLabel && !dangerRequiresReason
          ? `(required for ${primaryLabel})`
          : '(optional)';

  return (
    <section className="border-t border-slate-200 bg-white p-5 lg:p-6">
      <h2 className="text-base font-black text-cyanZone-ink">{title}</h2>
      <p className="mt-1 text-sm text-slate-500">{helperText}</p>
      <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_15rem]">
        <label className="text-sm font-bold text-slate-700">
          Decision reason{' '}
          <span className="font-medium text-slate-400">
            {requirementLabel}
          </span>
          <textarea
            aria-describedby={
              validationError ? 'decision-reason-error' : undefined
            }
            aria-invalid={validationError ? 'true' : undefined}
            className="mt-2 min-h-28 w-full resize-y rounded-lg border border-slate-300 px-3 py-3 text-sm font-normal leading-6 outline-none transition placeholder:text-slate-400 focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
            maxLength={500}
            onChange={(event) => {
              setValidationError(null);
              onReasonChange(event.target.value);
            }}
            placeholder="Provide a clear reason for your decision…"
            ref={reasonRef}
            value={reason}
          />
          <span
            className="mt-1 flex flex-wrap items-start gap-x-3 gap-y-1"
            data-testid="decision-reason-footer"
          >
            {validationError ? (
              <span
                className="min-w-0 flex-1 basis-72 text-sm font-semibold text-red-600"
                id="decision-reason-error"
                role="alert"
              >
                {validationError}
              </span>
            ) : null}
            <span
              className="ml-auto shrink-0 text-right text-xs font-medium text-slate-500"
              data-testid="decision-reason-count"
            >
              {reason.length} / 500
            </span>
          </span>
        </label>
        <div className="grid content-start gap-3 pt-7">
          <button
            className="inline-flex min-h-12 items-center justify-center gap-2 rounded-lg bg-cyanZone-cyan px-4 text-sm font-extrabold text-white transition hover:bg-cyan-700 focus:outline-none focus:ring-4 focus:ring-cyan-100 disabled:cursor-not-allowed disabled:opacity-45"
            disabled={isSubmitting}
            onClick={() =>
              runAction(primaryLabel, primaryRequiresReason, onPrimary)
            }
            type="button"
          >
            <Check className="h-4 w-4" aria-hidden="true" />
            {primaryLabel}
          </button>
          {dangerLabel && onDanger ? (
            <button
              className="inline-flex min-h-12 items-center justify-center gap-2 rounded-lg border border-red-300 bg-white px-4 text-sm font-extrabold text-red-600 transition hover:bg-red-50 focus:outline-none focus:ring-4 focus:ring-red-100 disabled:cursor-not-allowed disabled:opacity-45"
              disabled={isSubmitting || dangerDisabled}
              onClick={() =>
                runAction(dangerLabel, dangerRequiresReason, onDanger)
              }
              type="button"
            >
              <X className="h-4 w-4" aria-hidden="true" />
              {dangerLabel}
            </button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
