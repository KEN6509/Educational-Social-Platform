import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type { PageResult, UserDetailView, UserSummaryView } from '../../types/admin';
import { UsersPage } from './UsersPage';

const userSummary: UserSummaryView = {
  id: 'user-1',
  name: 'Lena Park',
  email: 'lena@cyanzone.test',
  avatarUrl: null,
  bio: 'Science educator',
  isContentCreator: false,
  isAdmin: false,
  accountStatus: 'active',
  createdAt: '2025-06-12T08:00:00.000Z',
};

const detail: UserDetailView = {
  ...userSummary,
  emailVerified: true,
  publishedPostCount: 0,
  recentPosts: [],
  recentDecisions: [],
};

function createApi() {
  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/users') {
        return {
          items: [userSummary],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<UserSummaryView>;
      }
      return detail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('UsersPage', () => {
  it('loads users, applies filters, and shows selected account evidence', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<UsersPage api={api} currentUserId="admin-1" />);

    expect(await screen.findByText('Lena Park')).toBeVisible();
    expect(await screen.findByText('Science educator')).toBeVisible();
    expect(screen.getByText('Verified email')).toBeVisible();

    await user.type(screen.getByRole('searchbox', { name: 'Search users' }), '  lena  ');
    await user.selectOptions(screen.getByLabelText('Account status'), 'active');
    await user.selectOptions(screen.getByLabelText('Creator status'), 'member');
    await user.click(screen.getByRole('button', { name: 'Apply filters' }));

    expect(api.get).toHaveBeenCalledWith('/admin/users', {
      page: 1,
      pageSize: 20,
      search: 'lena',
      accountStatus: 'active',
      creator: 'member',
    });
  });

  it('confirms account and creator changes with the preserved reason', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<UsersPage api={api} currentUserId="admin-1" />);

    await screen.findByText('Science educator');
    const reason = screen.getByLabelText(/Decision reason/);
    await user.type(reason, 'Repeatedly violated the community safety rules.');
    await user.click(screen.getByRole('button', { name: 'Suspend account' }));

    const dialog = screen.getByRole('dialog', { name: 'Suspend this account?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm suspension' }));
    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/account-status', {
      status: 'suspended',
      reason: 'Repeatedly violated the community safety rules.',
    });

    await user.clear(reason);
    await user.type(reason, 'Profile now meets the educational creator standard.');
    await user.click(screen.getByRole('button', { name: 'Assign creator' }));
    const creatorDialog = screen.getByRole('dialog', { name: 'Assign creator access?' });
    await user.click(within(creatorDialog).getByRole('button', { name: 'Confirm assignment' }));
    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/creator-status', {
      isCreator: true,
      reason: 'Profile now meets the educational creator standard.',
    });
  });

  it('does not allow an administrator to suspend their own account', async () => {
    const api = createApi();
    render(<UsersPage api={api} currentUserId="user-1" />);

    await screen.findByText('Science educator');
    expect(screen.getByRole('button', { name: 'Suspend account' })).toBeDisabled();
    expect(screen.getByText('You cannot suspend your own administrator account.')).toBeVisible();
    expect(screen.queryByRole('button', { name: /Delete/ })).not.toBeInTheDocument();
  });
});
