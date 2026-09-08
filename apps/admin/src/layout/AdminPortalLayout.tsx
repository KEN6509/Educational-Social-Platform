import {
  Bot,
  ClipboardList,
  FileWarning,
  LayoutDashboard,
  LogOut,
  Menu,
  ShieldCheck,
  UserRoundCheck,
  Users,
  X,
} from 'lucide-react';
import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { AdminLogoutDialog } from '../components/AdminLogoutDialog';

type QueueCounts = {
  creatorRequests: number;
  reports: number;
  appeals: number;
};

type Props = {
  email: string;
  onSignOut: () => Promise<string | null>;
  counts?: QueueCounts;
};

const navigation = [
  { to: '/', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/users', label: 'Users', icon: Users },
  {
    to: '/creator-requests',
    label: 'Creator Requests',
    icon: UserRoundCheck,
    countKey: 'creatorRequests' as const,
  },
  {
    to: '/reports',
    label: 'Reports',
    icon: FileWarning,
    countKey: 'reports' as const,
  },
  {
    to: '/appeals',
    label: 'Appeals',
    icon: ClipboardList,
    countKey: 'appeals' as const,
  },
  { to: '/ai-flagged', label: 'AI-Flagged Content', icon: Bot },
];

export function AdminPortalLayout({
  email,
  onSignOut,
  counts = { creatorRequests: 0, reports: 0, appeals: 0 },
}: Props) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [logoutOpen, setLogoutOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const [logoutError, setLogoutError] = useState<string | null>(null);

  async function confirmSignOut() {
    setSigningOut(true);
    setLogoutError(null);
    const error = await onSignOut();
    setSigningOut(false);
    if (error) setLogoutError(error);
    else setLogoutOpen(false);
  }

  const sidebar = (
    <>
      <div className="flex h-24 items-center gap-3 border-b border-slate-200 px-5">
        <span className="grid h-11 w-11 place-items-center rounded-xl bg-cyanZone-cyan text-white shadow-sm">
          <ShieldCheck className="h-6 w-6" aria-hidden="true" />
        </span>
        <span className="text-lg font-black leading-5 text-cyanZone-ink">
          CyanZone
          <span className="block">Admin</span>
        </span>
      </div>
      <nav aria-label="Casework desk" className="flex-1 px-3 py-6">
        <p className="px-3 text-[11px] font-bold uppercase tracking-[0.12em] text-slate-400">
          Casework desk
        </p>
        <div className="mt-4 space-y-1">
          {navigation.map(({ to, label, icon: Icon, countKey, end }) => (
            <NavLink
              className={({ isActive }) =>
                `flex min-h-11 items-center gap-3 rounded-lg px-3 text-sm font-bold transition ${
                  isActive
                    ? 'bg-cyan-50 text-cyan-700'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-950'
                }`
              }
              end={end}
              key={to}
              onClick={() => setMobileOpen(false)}
              to={to}
            >
              <Icon className="h-[18px] w-[18px]" aria-hidden="true" />
              <span className="flex-1">{label}</span>
              {countKey && counts[countKey] > 0 ? (
                <span className="min-w-6 rounded-full bg-cyan-100 px-2 py-0.5 text-center text-xs text-cyan-800">
                  {counts[countKey]}
                </span>
              ) : null}
            </NavLink>
          ))}
        </div>
      </nav>
      <div className="border-t border-slate-200 p-3">
        <div className="mb-2 flex items-center gap-3 rounded-lg px-3 py-3">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-cyanZone-cyan text-xs font-black text-white">
            {email.slice(0, 2).toUpperCase()}
          </span>
          <span className="min-w-0">
            <span className="block truncate text-sm font-extrabold text-slate-800">
              Administrator
            </span>
            <span className="block truncate text-xs text-slate-500">{email}</span>
          </span>
        </div>
        <button
          className="flex h-11 w-full items-center gap-3 rounded-lg px-3 text-sm font-bold text-slate-600 hover:bg-slate-50 hover:text-slate-950"
          onClick={() => setLogoutOpen(true)}
          type="button"
        >
          <LogOut className="h-[18px] w-[18px]" aria-hidden="true" />
          Log out
        </button>
      </div>
    </>
  );

  return (
    <div className="min-h-screen bg-white text-cyanZone-ink">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-slate-200 bg-white lg:flex">
        {sidebar}
      </aside>
      <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-white px-4 lg:hidden">
        <div className="flex items-center gap-2 font-black">
          <ShieldCheck className="h-5 w-5 text-cyanZone-cyan" />
          CyanZone Admin
        </div>
        <button
          aria-label="Open navigation"
          className="grid h-10 w-10 place-items-center rounded-lg border border-slate-200"
          onClick={() => setMobileOpen(true)}
          type="button"
        >
          <Menu className="h-5 w-5" />
        </button>
      </header>
      {mobileOpen ? (
        <div className="fixed inset-0 z-40 bg-slate-950/45 lg:hidden">
          <aside className="flex h-full w-[min(20rem,88vw)] flex-col bg-white shadow-2xl">
            <button
              aria-label="Close navigation"
              className="absolute right-4 top-4 grid h-10 w-10 place-items-center rounded-lg bg-white shadow"
              onClick={() => setMobileOpen(false)}
              type="button"
            >
              <X className="h-5 w-5" />
            </button>
            {sidebar}
          </aside>
        </div>
      ) : null}
      <main className="min-w-0 lg:pl-64">
        <Outlet />
      </main>
      <AdminLogoutDialog
        error={logoutError}
        isOpen={logoutOpen}
        isSigningOut={signingOut}
        onCancel={() => setLogoutOpen(false)}
        onConfirm={() => void confirmSignOut()}
      />
    </div>
  );
}
