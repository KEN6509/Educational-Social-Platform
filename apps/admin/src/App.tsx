import { AdminAuthBoundary } from './auth/AdminAuthBoundary';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { OverviewPage } from './features/overview/OverviewPage';
import { CreatorRequestsPage } from './features/creatorRequests/CreatorRequestsPage';
import { AppealsPage } from './features/appeals/AppealsPage';
import { AiFlaggedContentPage } from './features/aiFlagged/AiFlaggedContentPage';
import { ReportsPage } from './features/reports/ReportsPage';
import { UsersPage } from './features/users/UsersPage';
import { AdminPortalLayout } from './layout/AdminPortalLayout';

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
          <Routes>
            <Route
              element={
                <AdminPortalLayout
                  email={context.email}
                  onSignOut={context.signOut}
                />
              }
            >
              <Route
                index
                element={<OverviewPage />}
              />
              <Route
                path="users"
                element={<UsersPage currentUserId={context.session.userId} />}
              />
              <Route
                path="creator-requests"
                element={<CreatorRequestsPage />}
              />
              <Route
                path="reports"
                element={<ReportsPage />}
              />
              <Route
                path="appeals"
                element={<AppealsPage />}
              />
              <Route
                path="ai-flagged"
                element={<AiFlaggedContentPage />}
              />
            </Route>
          </Routes>
        </BrowserRouter>
      )}
    </AdminAuthBoundary>
  );
}
