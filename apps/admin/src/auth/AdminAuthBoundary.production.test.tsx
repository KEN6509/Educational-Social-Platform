import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

const { signOut } = vi.hoisted(() => ({
  signOut: vi.fn(async (_options?: { scope: 'local' }) => ({ error: null })),
}));

vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: async () => ({
        data: {
          session: {
            access_token: 'test-token',
            user: { id: 'admin-id', email: 'admin@example.com' },
          },
        },
      }),
      onAuthStateChange: () => ({
        data: { subscription: { unsubscribe: () => undefined } },
      }),
      signOut,
    },
  },
}));

import { AdminAuthBoundary } from './AdminAuthBoundary';

describe('production administrator logout', () => {
  it('signs out only this browser session', async () => {
    signOut.mockClear();
    render(
      <AdminAuthBoundary
        loadAdminProfile={async () => ({
          isAdmin: true,
          accountStatus: 'active',
        })}
      >
        {({ signOut: logOut }) => (
          <button onClick={() => void logOut()} type="button">
            Log out
          </button>
        )}
      </AdminAuthBoundary>,
    );

    fireEvent.click(await screen.findByRole('button', { name: 'Log out' }));
    expect(signOut).toHaveBeenCalledWith({ scope: 'local' });
  });
});
