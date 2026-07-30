import { useEffect } from 'react';
import { AlertTriangle, Loader2, LogOut, X } from 'lucide-react';

type AdminLogoutDialogProps = {
  isOpen: boolean;
  isSigningOut: boolean;
  error: string | null;
  onCancel: () => void;
  onConfirm: () => void;
};

export function AdminLogoutDialog({
  isOpen,
  isSigningOut,
  error,
  onCancel,
  onConfirm,
}: AdminLogoutDialogProps) {
  useEffect(() => {
    if (!isOpen) return;

    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape' && !isSigningOut) {
        onCancel();
      }
    }

    document.addEventListener('keydown', closeOnEscape);
    return () => document.removeEventListener('keydown', closeOnEscape);
  }, [isOpen, isSigningOut, onCancel]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center bg-cyanZone-ink/55 px-4 py-8 backdrop-blur-[2px]"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !isSigningOut) {
          onCancel();
        }
      }}
    >
      <section
        aria-describedby="logout-dialog-description"
        aria-labelledby="logout-dialog-title"
        aria-modal="true"
        className="w-full max-w-md overflow-hidden rounded-xl border border-slate-200 bg-white shadow-2xl shadow-slate-950/25"
        role="dialog"
      >
        <div className="h-1.5 bg-cyanZone-gold" />
        <div className="p-6 sm:p-7">
          <div className="flex items-start justify-between gap-4">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-amber-50 text-amber-700 ring-1 ring-amber-200">
              <AlertTriangle className="h-5 w-5" aria-hidden="true" />
            </div>
            <button
              aria-label="Close logout confirmation"
              className="grid h-9 w-9 place-items-center rounded-md text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 focus:outline-none focus:ring-4 focus:ring-cyan-100 disabled:cursor-not-allowed disabled:opacity-50"
              disabled={isSigningOut}
              onClick={onCancel}
              type="button"
            >
              <X className="h-5 w-5" aria-hidden="true" />
            </button>
          </div>

          <h2
            className="mt-5 text-2xl font-black tracking-tight text-cyanZone-ink"
            id="logout-dialog-title"
          >
            Log out of Admin Portal?
          </h2>
          <p
            className="mt-2 text-sm leading-6 text-slate-600"
            id="logout-dialog-description"
          >
            Your current administrator session will end. You will need to enter
            your credentials again to review CyanZone operations.
          </p>

          {error ? (
            <div
              className="mt-5 rounded-md border border-red-200 bg-red-50 px-3 py-2.5 text-sm font-semibold text-red-700"
              role="alert"
            >
              {error}
            </div>
          ) : null}

          <div className="mt-7 grid gap-3 sm:grid-cols-2">
            <button
              className="h-11 rounded-md border border-slate-300 bg-white px-4 text-sm font-bold text-slate-700 transition hover:bg-slate-50 focus:outline-none focus:ring-4 focus:ring-cyan-100 disabled:cursor-not-allowed disabled:opacity-50"
              disabled={isSigningOut}
              onClick={onCancel}
              type="button"
            >
              Stay signed in
            </button>
            <button
              className="inline-flex h-11 items-center justify-center gap-2 rounded-md bg-cyanZone-ink px-4 text-sm font-bold text-white transition hover:bg-black focus:outline-none focus:ring-4 focus:ring-amber-100 disabled:cursor-not-allowed disabled:opacity-60"
              disabled={isSigningOut}
              onClick={onConfirm}
              type="button"
            >
              {isSigningOut ? (
                <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
              ) : (
                <LogOut className="h-4 w-4" aria-hidden="true" />
              )}
              {isSigningOut ? 'Logging out…' : 'Log out'}
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}
