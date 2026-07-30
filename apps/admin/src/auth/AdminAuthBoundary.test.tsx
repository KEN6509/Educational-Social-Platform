import { render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import {
  AdminAuthBoundary,
  type AdminAuthAdapter,
} from './AdminAuthBoundary';

function createAdapter(
  session: AdminAuthAdapter['getSession'] extends () => Promise<infer T>
    ? T
    : never,
): AdminAuthAdapter {
  return {
    getSession: async () => session,
    onAuthStateChange: () => () => undefined,
    signIn: async () => null,
    signOut: async () => null,
  };
}

describe('AdminAuthBoundary', () => {
  it('shows the login when there is no session', async () => {
    render(
      <AdminAuthBoundary
        auth={createAdapter(null)}
        loadAdminProfile={vi.fn()}
      >
        {() => <div>Protected portal</div>}
      </AdminAuthBoundary>,
    );

    expect(screen.getByText('Checking admin access')).toBeInTheDocument();
    expect(
      await screen.findByRole('button', { name: 'Admin Sign In' }),
    ).toBeInTheDocument();
  });

  it('renders the portal for an active administrator', async () => {
    const session = {
      accessToken: 'token',
      userId: 'admin-id',
      email: 'admin@cyanzone.test',
    };
    render(
      <AdminAuthBoundary
        auth={createAdapter(session)}
        loadAdminProfile={async () => ({
          isAdmin: true,
          accountStatus: 'active',
        })}
      >
        {(context) => <div>Protected for {context.email}</div>}
      </AdminAuthBoundary>,
    );

    await waitFor(() => {
      expect(
        screen.getByText('Protected for admin@cyanzone.test'),
      ).toBeInTheDocument();
    });
  });

  it('signs out an account that is not an active administrator', async () => {
    const signOut = vi.fn(async () => null);
    const adapter = {
      ...createAdapter({
        accessToken: 'token',
        userId: 'member-id',
        email: 'member@cyanzone.test',
      }),
      signOut,
    };

    render(
      <AdminAuthBoundary
        auth={adapter}
        loadAdminProfile={async () => ({
          isAdmin: false,
          accountStatus: 'active',
        })}
      >
        {() => <div>Protected portal</div>}
      </AdminAuthBoundary>,
    );

    expect(
      await screen.findByText(
        'This account is not authorized for the admin dashboard.',
      ),
    ).toBeInTheDocument();
    expect(signOut).toHaveBeenCalled();
  });
});
