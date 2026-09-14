import { AdminAuthBoundary } from './auth/AdminAuthBoundary';
import { lazy, Suspense } from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { AdminPortalLayout } from './layout/AdminPortalLayout';

const OverviewPage = lazy(() =>
  import('./features/overview/OverviewPage').then((module) => ({
    default: module.OverviewPage,
  })),
);
const UsersPage = lazy(() =>
  import('./features/users/UsersPage').then((module) => ({
    default: module.UsersPage,
  })),
);
const CreatorRequestsPage = lazy(() =>
  import('./features/creatorRequests/CreatorRequestsPage').then(
    (module) => ({ default: module.CreatorRequestsPage }),
  ),
);
const ReportsPage = lazy(() =>
  import('./features/reports/ReportsPage').then((module) => ({
    default: module.ReportsPage,
  })),
);
const AppealsPage = lazy(() =>
  import('./features/appeals/AppealsPage').then((module) => ({
    default: module.AppealsPage,
  })),
);
const AiFlaggedContentPage = lazy(() =>
  import('./features/aiFlagged/AiFlaggedContentPage').then((module) => ({
    default: module.AiFlaggedContentPage,
  })),
);

function PlaceholderPage({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <section className="min-h-screen bg-white">
      <header className="border-b border-slate-200 px-5 py-6 lg:px-8">
        <h1 className="text-3xl font-black tracking-tight">{title}</h1>
        <p className="mt-1 text-sm text-slate-500">{description}</p>
      </header>
    </section>
  );
}

export function App() {
  return (
    <AdminAuthBoundary>
      {(context) => (
        <BrowserRouter>
          <Suspense
            fallback={
              <div className="grid min-h-screen place-items-center bg-slate-50 text-sm font-semibold text-slate-600">
                Loading administrator portal…
              </div>
            }
          >
            <Routes>
              <Route
                element={
                  <AdminPortalLayout
                    email={context.email}
                    onSignOut={context.signOut}
                  />
                }
              >
                <Route index element={<OverviewPage />} />
                <Route path="users" element={<UsersPage />} />
                <Route
                  path="creator-requests"
                  element={<CreatorRequestsPage />}
                />
                <Route path="reports" element={<ReportsPage />} />
                <Route path="appeals" element={<AppealsPage />} />
                <Route
                  path="ai-flagged"
                  element={<AiFlaggedContentPage />}
                />
              </Route>
            </Routes>
          </Suspense>
        </BrowserRouter>
      )}
    </AdminAuthBoundary>
  );
}
