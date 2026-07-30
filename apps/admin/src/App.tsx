import { AdminAuthBoundary } from './auth/AdminAuthBoundary';

export function App() {
  return (
    <AdminAuthBoundary>
      {(context) => (
        <main className="grid min-h-screen place-items-center bg-cyanZone-mist">
          <div className="rounded-xl border border-slate-200 bg-white p-8 text-center shadow-sm">
            <h1 className="text-2xl font-black">CyanZone Admin</h1>
            <p className="mt-2 text-sm text-slate-600">
              Signed in as {context.email}
            </p>
          </div>
        </main>
      )}
    </AdminAuthBoundary>
  );
}
