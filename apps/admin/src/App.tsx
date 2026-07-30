import { AdminAuthBoundary } from './auth/AdminAuthBoundary';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

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
                element={
                  <PlaceholderPage
                    title="Overview"
                    description="Prioritized queues and recent casework decisions."
                  />
                }
              />
              <Route
                path="users"
                element={
                  <PlaceholderPage
                    title="Users"
                    description="Review accounts, access, and creator status."
                  />
                }
              />
              <Route
                path="creator-requests"
                element={
                  <PlaceholderPage
                    title="Creator Requests"
                    description="Review and decide on creator applications."
                  />
                }
              />
              <Route
                path="reports"
                element={
                  <PlaceholderPage
                    title="Reports"
                    description="Review grouped content cases reported by the community."
                  />
                }
              />
              <Route
                path="appeals"
                element={
                  <PlaceholderPage
                    title="Appeals"
                    description="Review rejected content and member appeals."
                  />
                }
              />
              <Route
                path="ai-flagged"
                element={
                  <PlaceholderPage
                    title="AI-Flagged Content"
                    description="Preview the future AI moderation review workflow."
                  />
                }
              />
            </Route>
          </Routes>
        </BrowserRouter>
      )}
    </AdminAuthBoundary>
  );
}
