import { useEffect, useState, type FormEvent } from 'react';
import type { Session } from '@supabase/supabase-js';
import {
  Flag,
  Loader2,
  LockKeyhole,
  LogOut,
  ShieldCheck,
  UserCheck,
  Users,
} from 'lucide-react';

import { AdminLogoutDialog } from './components/AdminLogoutDialog';
import { supabase } from './lib/supabase';

const metrics = [
  { label: 'Users', value: '0', icon: Users },
  { label: 'Creator Requests', value: '0', icon: UserCheck },
  { label: 'Moderation Queue', value: '0', icon: ShieldCheck },
  { label: 'Reports', value: '0', icon: Flag },
];

type AuthStatus = 'checking' | 'signed-out' | 'authorized';

export function App() {
  const [status, setStatus] = useState<AuthStatus>('checking');
  const [session, setSession] = useState<Session | null>(null);
  const [authMessage, setAuthMessage] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function loadSession() {
      const { data } = await supabase.auth.getSession();
      if (!isMounted) return;
      await resolveAdminSession(data.session);
    }

    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (_event, nextSession) => {
        await resolveAdminSession(nextSession);
      },
    );

    loadSession();

    return () => {
      isMounted = false;
      authListener.subscription.unsubscribe();
    };
  }, []);

  async function resolveAdminSession(nextSession: Session | null) {
    setAuthMessage(null);

    if (!nextSession) {
      setSession(null);
      setStatus('signed-out');
      return;
    }

    setStatus('checking');

    const { data, error } = await supabase
      .from('profiles')
      .select('is_admin, account_status')
      .eq('id', nextSession.user.id)
      .maybeSingle();

    if (error || !data?.is_admin || data.account_status !== 'active') {
      await supabase.auth.signOut();
      setSession(null);
      setStatus('signed-out');
      setAuthMessage('This account is not authorized for the admin dashboard.');
      return;
    }

    setSession(nextSession);
    setStatus('authorized');
  }

  if (status === 'checking') {
    return <LoadingScreen />;
  }

  if (status === 'signed-out') {
    return <AdminLogin message={authMessage} />;
  }

  return <Dashboard email={session?.user.email ?? 'Admin'} />;
}

function LoadingScreen() {
  return (
    <main className="grid min-h-screen place-items-center bg-[#F4FAFA] text-[#172026]">
      <div className="flex items-center gap-3 rounded-md border border-slate-200 bg-white px-4 py-3 shadow-sm">
        <Loader2 className="h-5 w-5 animate-spin text-cyanZone-cyan" />
        <span className="text-sm font-semibold">Checking admin access</span>
      </div>
    </main>
  );
}

function AdminLogin({ message }: { message: string | null }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [localMessage, setLocalMessage] = useState<string | null>(message);

  useEffect(() => {
    setLocalMessage(message);
  }, [message]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsLoading(true);
    setLocalMessage(null);

    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (error) {
      setLocalMessage(error.message);
    }

    setIsLoading(false);
  }

  return (
    <main className="min-h-screen bg-[#F4FAFA] text-[#172026]">
      <section className="grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
        <div className="flex items-center px-5 py-10 sm:px-8 lg:px-14">
          <div className="mx-auto w-full max-w-md">
            <div className="mb-8 inline-flex h-14 w-14 items-center justify-center rounded-md bg-cyanZone-cyan text-white shadow-lg shadow-cyan-700/20">
              <ShieldCheck className="h-7 w-7" />
            </div>
            <h1 className="text-3xl font-black tracking-tight sm:text-4xl">
              CyanZone Admin
            </h1>
            <p className="mt-3 max-w-sm text-sm leading-6 text-slate-600">
              Sign in with the approved admin account to manage creator approvals,
              moderation, reports, and safety workflows.
            </p>

            <form
              className="mt-8 rounded-md border border-slate-200 bg-white p-5 shadow-xl shadow-cyan-950/5"
              onSubmit={handleSubmit}
            >
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-semibold text-slate-700">
                    Email
                  </span>
                  <input
                    className="mt-2 h-12 w-full rounded-md border border-slate-300 px-3 text-base outline-none transition focus:border-cyanZone-cyan focus:ring-4 focus:ring-cyan-100"
                    type="email"
                    autoComplete="email"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    required
                  />
                </label>
                <label className="block">
                  <span className="text-sm font-semibold text-slate-700">
                    Password
                  </span>
                  <input
                    className="mt-2 h-12 w-full rounded-md border border-slate-300 px-3 text-base outline-none transition focus:border-cyanZone-cyan focus:ring-4 focus:ring-cyan-100"
                    type="password"
                    autoComplete="current-password"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    required
                    minLength={8}
                  />
                </label>
              </div>

              {localMessage ? (
                <div className="mt-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm font-medium text-red-700">
                  {localMessage}
                </div>
              ) : null}

              <button
                className="mt-5 inline-flex h-12 w-full items-center justify-center gap-2 rounded-md bg-[#172026] px-4 text-sm font-bold text-white transition hover:bg-black focus:outline-none focus:ring-4 focus:ring-cyan-100 disabled:cursor-not-allowed disabled:opacity-60"
                type="submit"
                disabled={isLoading}
              >
                {isLoading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <LockKeyhole className="h-4 w-4" />
                )}
                Admin Sign In
              </button>
            </form>
          </div>
        </div>

        <div className="hidden bg-[#172026] p-10 text-white lg:flex lg:items-end">
          <div>
            <div className="mb-5 inline-flex rounded-md bg-white/10 px-3 py-2 text-sm font-bold text-cyan-100">
              Parent-supervised learning
            </div>
            <p className="max-w-xl text-3xl font-black leading-tight">
              Keep the demo focused: approve creators, review reports, and keep
              teen learning spaces calm.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}

function Dashboard({ email }: { email: string }) {
  const [isLogoutOpen, setIsLogoutOpen] = useState(false);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [logoutError, setLogoutError] = useState<string | null>(null);

  function closeLogoutDialog() {
    if (isSigningOut) return;
    setIsLogoutOpen(false);
    setLogoutError(null);
  }

  async function confirmLogout() {
    if (isSigningOut) return;

    setIsSigningOut(true);
    setLogoutError(null);
    const { error } = await supabase.auth.signOut();

    if (error) {
      setLogoutError(
        'Could not log out. Please check your connection and try again.',
      );
      setIsSigningOut(false);
    }
  }

  return (
    <main className="min-h-screen bg-cyanZone-mist text-cyanZone-ink">
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-slate-200 bg-white px-5 py-6 lg:block">
        <div className="text-xl font-black">CyanZone Admin</div>
        <nav className="mt-8 space-y-2 text-sm font-semibold text-slate-600">
          <a
            className="block rounded-md bg-cyanZone-mist px-3 py-2 text-cyanZone-ink"
            href="/"
          >
            Overview
          </a>
          <a className="block rounded-md px-3 py-2 hover:bg-slate-100" href="/">
            Users
          </a>
          <a className="block rounded-md px-3 py-2 hover:bg-slate-100" href="/">
            Moderation
          </a>
          <a className="block rounded-md px-3 py-2 hover:bg-slate-100" href="/">
            Reports
          </a>
        </nav>
      </aside>

      <section className="lg:pl-64">
        <header className="flex items-center justify-between border-b border-slate-200 bg-white px-5 py-4">
          <div>
            <h1 className="text-lg font-bold">Dashboard</h1>
            <p className="text-sm text-slate-500">
              Signed in as {email}. Creator approval, moderation, and reports
              will connect here in Phase 5.
            </p>
          </div>
          <button
            className="inline-flex h-10 items-center gap-2 rounded-md border border-slate-200 bg-white px-3 text-sm font-bold text-slate-700 transition hover:bg-slate-50 focus:outline-none focus:ring-4 focus:ring-cyan-100"
            type="button"
            onClick={() => {
              setLogoutError(null);
              setIsLogoutOpen(true);
            }}
          >
            <LogOut className="h-4 w-4" />
            Log out
          </button>
        </header>

        <div className="grid gap-4 p-5 sm:grid-cols-2 xl:grid-cols-4">
          {metrics.map((metric) => {
            const Icon = metric.icon;
            return (
              <article
                key={metric.label}
                className="rounded-md border border-slate-200 bg-white p-4 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-semibold text-slate-500">
                    {metric.label}
                  </span>
                  <Icon className="h-5 w-5 text-cyanZone-cyan" />
                </div>
                <div className="mt-3 text-3xl font-black">{metric.value}</div>
              </article>
            );
          })}
        </div>
      </section>

      <AdminLogoutDialog
        error={logoutError}
        isOpen={isLogoutOpen}
        isSigningOut={isSigningOut}
        onCancel={closeLogoutDialog}
        onConfirm={confirmLogout}
      />
    </main>
  );
}
