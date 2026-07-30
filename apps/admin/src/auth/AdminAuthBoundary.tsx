import {
  useEffect,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react';
import { Loader2, LockKeyhole, ShieldCheck } from 'lucide-react';

import { supabase } from '../lib/supabase';

export type AdminSession = {
  accessToken: string;
  userId: string;
  email: string;
};

export type AdminAuthAdapter = {
  getSession: () => Promise<AdminSession | null>;
  onAuthStateChange: (
    callback: (session: AdminSession | null) => void,
  ) => () => void;
  signIn: (email: string, password: string) => Promise<string | null>;
  signOut: () => Promise<string | null>;
};

type AdminProfile = {
  isAdmin: boolean;
  accountStatus: string;
};

export type AdminAuthContext = {
  email: string;
  session: AdminSession;
  signOut: () => Promise<string | null>;
};

type Props = {
  children: (context: AdminAuthContext) => ReactNode;
  auth?: AdminAuthAdapter;
  loadAdminProfile?: (userId: string) => Promise<AdminProfile | null>;
};

const productionAuth: AdminAuthAdapter = {
  getSession: async () => {
    const { data } = await supabase.auth.getSession();
    if (!data.session) return null;
    return {
      accessToken: data.session.access_token,
      userId: data.session.user.id,
      email: data.session.user.email ?? 'Admin',
    };
  },
  onAuthStateChange: (callback) => {
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      callback(
        session
          ? {
              accessToken: session.access_token,
              userId: session.user.id,
              email: session.user.email ?? 'Admin',
            }
          : null,
      );
    });
    return () => data.subscription.unsubscribe();
  },
  signIn: async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return error?.message ?? null;
  },
  signOut: async () => {
    const { error } = await supabase.auth.signOut();
    return error?.message ?? null;
  },
};

async function productionProfileLoader(userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('is_admin, account_status')
    .eq('id', userId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    isAdmin: data.is_admin,
    accountStatus: data.account_status,
  };
}

export function AdminAuthBoundary({
  children,
  auth = productionAuth,
  loadAdminProfile = productionProfileLoader,
}: Props) {
  const [status, setStatus] = useState<
    'checking' | 'signed-out' | 'authorized'
  >('checking');
  const [session, setSession] = useState<AdminSession | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    const resolve = async (nextSession: AdminSession | null) => {
      if (!active) return;
      setMessage(null);
      if (!nextSession) {
        setSession(null);
        setStatus('signed-out');
        return;
      }

      setStatus('checking');
      const profile = await loadAdminProfile(nextSession.userId);
      if (!active) return;
      if (
        !profile?.isAdmin ||
        profile.accountStatus !== 'active'
      ) {
        await auth.signOut();
        if (!active) return;
        setSession(null);
        setStatus('signed-out');
        setMessage(
          'This account is not authorized for the admin dashboard.',
        );
        return;
      }

      setSession(nextSession);
      setStatus('authorized');
    };

    void auth.getSession().then(resolve);
    const unsubscribe = auth.onAuthStateChange((nextSession) => {
      void resolve(nextSession);
    });

    return () => {
      active = false;
      unsubscribe();
    };
  }, [auth, loadAdminProfile]);

  if (status === 'checking') {
    return (
      <main className="grid min-h-screen place-items-center bg-[#f4fafa]">
        <div className="flex items-center gap-3 rounded-lg border border-slate-200 bg-white px-4 py-3">
          <Loader2 className="h-5 w-5 animate-spin text-cyan-600" />
          <span className="text-sm font-semibold">Checking admin access</span>
        </div>
      </main>
    );
  }

  if (status === 'signed-out' || !session) {
    return <AdminLogin auth={auth} message={message} />;
  }

  return children({
    email: session.email,
    session,
    signOut: auth.signOut,
  });
}

function AdminLogin({
  auth,
  message,
}: {
  auth: AdminAuthAdapter;
  message: string | null;
}) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [localMessage, setLocalMessage] = useState(message);
  const [busy, setBusy] = useState(false);

  useEffect(() => setLocalMessage(message), [message]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setLocalMessage(null);
    setLocalMessage(await auth.signIn(email.trim(), password));
    setBusy(false);
  }

  return (
    <main className="grid min-h-screen bg-[#f4fafa] lg:grid-cols-2">
      <section className="flex items-center px-6 py-12">
        <div className="mx-auto w-full max-w-md">
          <div className="mb-7 grid h-14 w-14 place-items-center rounded-xl bg-cyan-600 text-white">
            <ShieldCheck className="h-7 w-7" />
          </div>
          <h1 className="text-4xl font-black">CyanZone Admin</h1>
          <p className="mt-3 text-sm leading-6 text-slate-600">
            Sign in with an active administrator account.
          </p>
          <form
            className="mt-8 space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-xl shadow-cyan-950/5"
            onSubmit={submit}
          >
            <label className="block text-sm font-bold">
              Email
              <input
                className="mt-2 h-12 w-full rounded-lg border border-slate-300 px-3"
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                required
              />
            </label>
            <label className="block text-sm font-bold">
              Password
              <input
                className="mt-2 h-12 w-full rounded-lg border border-slate-300 px-3"
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                required
              />
            </label>
            {localMessage ? (
              <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">
                {localMessage}
              </p>
            ) : null}
            <button
              className="flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-slate-950 font-bold text-white disabled:opacity-60"
              type="submit"
              disabled={busy}
            >
              {busy ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <LockKeyhole className="h-4 w-4" />
              )}
              Admin Sign In
            </button>
          </form>
        </div>
      </section>
      <aside className="hidden bg-slate-950 p-12 text-white lg:flex lg:items-end">
        <p className="max-w-lg text-3xl font-black">
          Review people and content with context, care, and a clear audit
          trail.
        </p>
      </aside>
    </main>
  );
}
