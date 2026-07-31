import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type {
  AdminPostDetailView,
  PageResult,
  PostSummaryView,
  UserDetailView,
  UserSummaryView,
} from '../../types/admin';
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

const publishedPosts: PostSummaryView[] = Array.from(
  { length: 8 },
  (_, index) => ({
    id: `post-${index + 1}`,
    title: index === 0 ? 'Repair guide' : `Post ${index + 1}`,
    content: `Complete content ${index + 1}`,
    tags: ['Technology'],
    moderationStatus: 'approved',
    publishedAt: '2026-07-31T08:00:00.000Z',
    createdAt: '2026-07-31T08:00:00.000Z',
    coverImageUrl: null,
    imageCount: 0,
    commentCount: 1,
  }),
);

const postDetail: AdminPostDetailView = {
  ...publishedPosts[0]!,
  authorId: 'user-1',
  authorName: 'Lena Park',
  authorAvatarUrl: null,
  images: [],
  comments: [],
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

function createPostReviewApi() {
  const creatorDetail: UserDetailView = {
    ...detail,
    isContentCreator: true,
    publishedPostCount: publishedPosts.length,
    recentPosts: publishedPosts.slice(0, 5),
  };

  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/users') {
        return {
          items: [{ ...userSummary, isContentCreator: true }],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<UserSummaryView>;
      }
      if (path === '/admin/users/user-1') return creatorDetail;
      if (path === '/admin/users/user-1/posts') return publishedPosts;
      if (path === '/admin/posts/post-1') return postDetail;
      throw new Error(`Unexpected GET ${path}`);
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('UsersPage', () => {
  it('loads users, applies filters, and shows selected account evidence', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<UsersPage api={api} />);

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

  it('confirms creator changes with the preserved reason', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<UsersPage api={api} />);

    await screen.findByText('Science educator');
    const reason = screen.getByLabelText(/Decision reason/);
    await user.type(reason, 'Profile now meets the educational creator standard.');
    await user.click(screen.getByRole('button', { name: 'Assign creator' }));
    const creatorDialog = screen.getByRole('dialog', { name: 'Assign creator access?' });
    await user.click(within(creatorDialog).getByRole('button', { name: 'Confirm assignment' }));
    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/creator-status', {
      isCreator: true,
      reason: 'Profile now meets the educational creator standard.',
    });
  });

  it('does not expose account suspension actions', async () => {
    const api = createApi();
    render(<UsersPage api={api} />);

    await screen.findByText('Science educator');
    expect(screen.queryByRole('button', { name: 'Suspend account' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reactivate account' })).not.toBeInTheDocument();
    expect(screen.queryByText('You cannot suspend your own administrator account.')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Delete/ })).not.toBeInTheDocument();
  });

  it('reviews recent and all creator posts while preserving the all-posts modal', async () => {
    const user = userEvent.setup();
    const api = createPostReviewApi();
    render(<UsersPage api={api} />);

    const identity = await screen.findByTestId('user-identity');
    expect(
      within(identity).getByLabelText('Verified content creator'),
    ).toBeVisible();
    expect(within(identity).queryByText('Approved')).not.toBeInTheDocument();
    const publishedFact = screen.getByText('Published posts').parentElement!;
    expect(within(publishedFact).getByText('8')).toBeVisible();
    expect(
      screen.getAllByRole('button', { name: /Open post/ }),
    ).toHaveLength(5);

    await user.click(screen.getByRole('button', { name: 'See all posts' }));
    expect(api.get).toHaveBeenCalledWith('/admin/users/user-1/posts');
    const allPosts = await screen.findByRole('dialog', {
      name: 'All published posts',
    });
    await user.click(
      within(allPosts).getByRole('button', { name: 'Open post Repair guide' }),
    );

    expect(api.get).toHaveBeenCalledWith('/admin/posts/post-1');
    const postDialog = await screen.findByRole('dialog', {
      name: 'Repair guide',
    });
    await user.click(
      within(postDialog).getByRole('button', { name: 'Back to all posts' }),
    );
    expect(
      screen.getByRole('dialog', { name: 'All published posts' }),
    ).toBeVisible();
  });
});
