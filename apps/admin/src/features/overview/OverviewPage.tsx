import {
  ArrowRight,
  ClipboardList,
  FileWarning,
  History,
  UserRoundCheck,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { AsyncState } from '../../components/casework/AsyncState';
import { adminApi, type AdminApi } from '../../lib/adminApi';
import type { OverviewView } from '../../types/admin';

export function OverviewPage({ api = adminApi }: { api?: AdminApi }) {
  const [data, setData] = useState<OverviewView | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let active = true;
    setError(null);
    void api
      .get<OverviewView>('/admin/overview')
      .then((result) => {
        if (active) setData(result);
      })
      .catch((nextError: unknown) => {
        if (active) {
          setError(
            nextError instanceof Error
              ? nextError.message
              : 'Overview could not be loaded.',
          );
        }
      });
    return () => {
      active = false;
    };
  }, [api, reload]);

  return (
    <section className="min-h-screen bg-[#fbfdfd]">
      <header className="border-b border-slate-200 bg-white px-5 py-6 lg:px-8">
        <h1 className="text-3xl font-black tracking-tight">Overview</h1>
        <p className="mt-1 text-sm text-slate-500">
          Prioritized queues and recent casework decisions.
        </p>
      </header>

      {!data && !error ? <AsyncState state="loading" /> : null}
      {error ? (
        <AsyncState
          errorMessage={error}
          onRetry={() => setReload((value) => value + 1)}
          state="error"
        />
      ) : null}
      {data ? (
        <div className="mx-auto max-w-6xl space-y-8 p-5 lg:p-8">
          <section aria-labelledby="priority-queues">
            <h2 className="text-lg font-black" id="priority-queues">
              Priority queues
            </h2>
            <div className="mt-4 divide-y divide-slate-200 overflow-hidden rounded-xl border border-slate-200 bg-white">
              <QueueLink
                count={data.pendingCreatorRequests}
                description="Applications waiting for profile and content review."
                icon={UserRoundCheck}
                label="Creator Requests"
                to="/creator-requests"
              />
              <QueueLink
                count={data.pendingReportCases}
                description="Grouped cases meeting the three-reporter review threshold."
                icon={FileWarning}
                label="Report cases"
                to="/reports"
              />
              <QueueLink
                count={data.pendingAppeals}
                description="Members requesting another review of rejected content."
                icon={ClipboardList}
                label="Appeals"
                to="/appeals"
              />
            </div>
          </section>

          <section aria-labelledby="recent-decisions">
            <div className="flex items-center gap-2">
              <History className="h-5 w-5 text-cyan-700" aria-hidden="true" />
              <h2 className="text-lg font-black" id="recent-decisions">
                Recent decisions
              </h2>
            </div>
            {data.recentDecisions.length === 0 ? (
              <div className="mt-4 rounded-xl border border-slate-200 bg-white">
                <AsyncState
                  emptyMessage="No administrator decisions have been recorded yet."
                  state="empty"
                />
              </div>
            ) : (
              <div className="mt-4 divide-y divide-slate-200 overflow-hidden rounded-xl border border-slate-200 bg-white">
                {data.recentDecisions.map((decision) => (
                  <article
                    className="grid gap-2 px-5 py-4 sm:grid-cols-[1fr_auto]"
                    key={decision.id}
                  >
                    <div>
                      <p className="text-sm font-extrabold text-slate-800">
                        {readableAction(decision.actionType)}
                      </p>
                      <p className="mt-1 text-sm leading-6 text-slate-600">
                        {decision.reason}
                      </p>
                    </div>
                    <div className="text-xs text-slate-500 sm:text-right">
                      <p>{decision.adminEmail ?? 'Administrator'}</p>
                      <time dateTime={decision.createdAt}>
                        {formatDateTime(decision.createdAt)}
                      </time>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        </div>
      ) : null}
    </section>
  );
}

function QueueLink({
  to,
  label,
  description,
  count,
  icon: Icon,
}: {
  to: string;
  label: string;
  description: string;
  count: number;
  icon: typeof UserRoundCheck;
}) {
  return (
    <Link
      className="group flex items-center gap-4 px-5 py-5 transition hover:bg-cyan-50/60 focus:outline-none focus:ring-4 focus:ring-inset focus:ring-cyan-100"
      to={to}
    >
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-cyan-50 text-cyan-700">
        <Icon className="h-5 w-5" aria-hidden="true" />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2 text-base font-black">
          {label}
          <span className="rounded-full bg-amber-100 px-2.5 py-0.5 text-xs text-amber-800">
            {count}
          </span>
        </span>
        <span className="mt-1 block text-sm text-slate-500">
          {description}
        </span>
      </span>
      <ArrowRight className="h-5 w-5 text-slate-300 transition group-hover:translate-x-0.5 group-hover:text-cyan-600" />
    </Link>
  );
}

function readableAction(action: string) {
  return action
    .replace(/[._]/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('en-MY', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
