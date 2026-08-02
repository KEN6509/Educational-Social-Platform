import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type {
  AdminPostDetailView,
  CreatorRequestDetailView,
  CreatorRequestSummaryView,
  PageResult,
} from '../../types/admin';
import { CreatorRequestsPage } from './CreatorRequestsPage';

const summary: CreatorRequestSummaryView = {
  id: 'request-1',
  userId: 'user-1',
  userName: 'Lena Park',
  userEmail: 'lena@cyanzone.test',
  avatarUrl: null,
  reason: 'I create practical science lessons for teenagers.',
  status: 'pending',
  createdAt: '2026-07-30T15:28:00.000Z',
  reviewedAt: null,
};

const detail: CreatorRequestDetailView = {
  ...summary,
  accountStatus: 'active',
  isContentCreator: false,
  memberSince: '2025-06-12T08:00:00.000Z',
  bio: 'Former science teacher creating hands-on experiments.',
  adminNote: null,
  reviewedBy: null,
  recentPosts: [
    {
      id: 'post-1',
      title: 'Build a Lemon Battery',
      content: 'Discover how lemons can generate electricity.',
      tags: ['Science'],
      moderationStatus: 'approved',
      publishedAt: '2026-07-28T08:00:00.000Z',
      createdAt: '2026-07-28T08:00:00.000Z',
      coverImageUrl: null,
      imageCount: 0,
      commentCount: 0,
    },
  ],
  recentDecisions: [],
};

const postDetail: AdminPostDetailView = {
  ...detail.recentPosts[0]!,
  authorId: 'user-1',
  authorName: 'Lena Park',
  authorAvatarUrl: null,
  images: [],
  comments: [],
};

function createApi() {
  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/creator-requests') {
        return {
          items: [summary],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<CreatorRequestSummaryView>;
      }
      if (path === '/admin/posts/post-1') return postDetail;
      return detail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('CreatorRequestsPage', () => {
  it('renders status tabs, the request inbox, and profile evidence', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<CreatorRequestsPage api={api} />);

    expect(await screen.findByText('Lena Park')).toBeVisible();
    expect(
      await screen.findByText(
        'Former science teacher creating hands-on experiments.',
      ),
    ).toBeVisible();
    expect(screen.getByText('Build a Lemon Battery')).toBeVisible();
    expect(
      screen.getByTestId('recent-post-media-post-1'),
    ).toBeVisible();
    expect(
      screen.getAllByText(
        'I create practical science lessons for teenagers.',
      ),
    ).toHaveLength(2);

    await user.click(screen.getByRole('tab', { name: 'Approved' }));
    expect(api.get).toHaveBeenCalledWith('/admin/creator-requests', {
      page: 1,
      pageSize: 20,
      search: '',
      status: 'approved',
    });
  });

  it('reuses the Users post card and opens the shared post detail', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<CreatorRequestsPage api={api} />);

    await user.click(
      await screen.findByRole('button', {
        name: 'Open post Build a Lemon Battery',
      }),
    );

    expect(api.get).toHaveBeenCalledWith('/admin/posts/post-1');
    expect(
      await screen.findByRole('dialog', { name: 'Build a Lemon Battery' }),
    ).toBeVisible();
  });

  it('requires a reason and confirms approval or rejection', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<CreatorRequestsPage api={api} />);
    await screen.findByText('Build a Lemon Battery');

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'Profile and educational content meet creator standards.',
    );
    await user.click(screen.getByRole('button', { name: 'Approve creator' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve this creator request?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));

    expect(api.post).toHaveBeenCalledWith(
      '/admin/creator-requests/request-1/decision',
      {
        decision: 'approved',
        reason: 'Profile and educational content meet creator standards.',
      },
    );
  });

  it('requires and sends the administrator reason when rejecting', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<CreatorRequestsPage api={api} />);
    await screen.findByText('Build a Lemon Battery');

    await user.click(screen.getByRole('button', { name: 'Reject request' }));
    expect(screen.getByRole('alert')).toHaveTextContent(
      'Enter a reason between 10 and 500 characters before choosing "Reject request".',
    );
    expect(api.post).not.toHaveBeenCalled();

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'The account needs more original educational content.',
    );
    await user.click(screen.getByRole('button', { name: 'Reject request' }));
    const dialog = screen.getByRole('dialog', {
      name: 'Reject this creator request?',
    });
    expect(dialog).toHaveTextContent(
      'The request will be rejected and the requester will receive your reason.',
    );
    await user.click(
      within(dialog).getByRole('button', { name: 'Confirm rejection' }),
    );

    expect(api.post).toHaveBeenCalledWith(
      '/admin/creator-requests/request-1/decision',
      {
        decision: 'rejected',
        reason: 'The account needs more original educational content.',
      },
    );
  });
});
