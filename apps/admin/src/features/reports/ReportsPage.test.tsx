import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type {
  AdminPostDetailView,
  PageResult,
  ReportCaseDetailView,
  ReportCaseSummaryView,
} from '../../types/admin';
import { ReportsPage } from './ReportsPage';

const summary: ReportCaseSummaryView = {
  targetType: 'post',
  targetId: 'post-1',
  targetTitle: 'Why Sleep Matters',
  targetExcerpt: 'Sleep is optional if you really want to succeed.',
  ownerName: 'Jordan Lee',
  status: 'pending_review',
  totalReports: 7,
  uniqueReporters: 7,
  reasonCounts: [
    { reason: 'Harmful advice', count: 5 },
    { reason: 'Misinformation', count: 2 },
  ],
  latestReportedAt: '2026-07-31T08:00:00.000Z',
};

const detail: ReportCaseDetailView = {
  ...summary,
  ownerId: 'owner-1',
  ownerEmail: 'jordan@cyanzone.test',
  content: 'Sleep is optional if you really want to succeed.',
  moderationStatus: 'approved',
  publishedAt: '2026-07-30T08:00:00.000Z',
  reports: [
    {
      id: 'report-1',
      reporterId: 'reporter-1',
      reason: 'Harmful advice',
      status: 'pending_review',
      createdAt: '2026-07-31T08:00:00.000Z',
      reviewedAt: null,
      resolutionNote: null,
    },
  ],
  recentDecisions: [],
};

const postDetail: AdminPostDetailView = {
  id: 'post-1',
  authorId: 'owner-1',
  authorName: 'Jordan Lee',
  authorAvatarUrl: null,
  title: 'Why Sleep Matters',
  content: 'Sleep is optional if you really want to succeed.',
  tags: ['Health'],
  moderationStatus: 'approved',
  publishedAt: '2026-07-30T08:00:00.000Z',
  createdAt: '2026-07-30T08:00:00.000Z',
  coverImageUrl: 'https://images.test/sleep.jpg',
  imageCount: 1,
  commentCount: 1,
  images: [{ url: 'https://images.test/sleep.jpg', position: 1 }],
  comments: [
    {
      id: 'comment-1',
      authorId: 'member-1',
      authorName: 'Aisha',
      authorAvatarUrl: null,
      isCreator: false,
      content: 'This advice feels unsafe.',
      createdAt: '2026-07-31T09:00:00.000Z',
      likeCount: 2,
      replies: [],
    },
  ],
};

function createApi() {
  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/report-cases') {
        return {
          items: [summary],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<ReportCaseSummaryView>;
      }
      if (path === '/admin/posts/post-1') return postDetail;
      return detail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('ReportsPage', () => {
  it('renders grouped report totals, reason percentages, and visibility', async () => {
    const api = createApi();
    render(<ReportsPage api={api} />);

    expect(await screen.findByText('Why Sleep Matters')).toBeVisible();
    expect(await screen.findByText('7 total reports')).toBeVisible();
    expect(screen.getByText('7 unique reporters')).toBeVisible();
    expect(screen.getByText('Harmful advice')).toBeVisible();
    expect(screen.getByText('5 · 71%')).toBeVisible();
    expect(screen.getByText('2 · 29%')).toBeVisible();
    expect(screen.getByRole('img', { name: 'Report reasons' })).toBeVisible();
    expect(screen.getByText('Currently visible')).toBeVisible();
    expect(screen.getByText('1 case')).toBeVisible();
    expect(screen.queryByText('7 cases')).not.toBeInTheDocument();
  });

  it('uses only the simplified report tabs and pending-review query', async () => {
    const api = createApi();
    render(<ReportsPage api={api} />);

    expect(await screen.findByRole('tab', { name: 'Pending Review' })).toBeVisible();
    expect(screen.queryByRole('tab', { name: 'Reviewing' })).not.toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Resolved' })).toBeVisible();
    expect(screen.getByRole('tab', { name: 'Dismissed' })).toBeVisible();
    expect(api.get).toHaveBeenCalledWith(
      '/admin/report-cases',
      expect.objectContaining({ status: 'pending_review' }),
    );
    expect(screen.queryByText('Reporter context')).not.toBeInTheDocument();
  });

  it('opens the shared post detail popup from a post report', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<ReportsPage api={api} />);

    await user.click(await screen.findByRole('button', { name: 'View Post >' }));

    expect(api.get).toHaveBeenCalledWith('/admin/posts/post-1');
    expect(await screen.findByRole('dialog', { name: 'Why Sleep Matters' })).toBeVisible();
    expect(screen.getByText('This advice feels unsafe.')).toBeVisible();
  });

  it('limits each left-panel content preview to two lines', async () => {
    const api = createApi();
    render(<ReportsPage api={api} />);

    const queue = await screen.findByLabelText('Casework queue');
    const item = within(queue).getByRole('button', {
      name: /Why Sleep Matters/,
    });
    expect(
      within(item).getByText('7 reports · 7 reporters'),
    ).toBeVisible();
    expect(within(item).getByText(summary.targetExcerpt)).toHaveClass(
      'line-clamp-2',
    );
  });

  it('confirms removal with a required administrator reason', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<ReportsPage api={api} />);
    await screen.findByText('7 total reports');

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'The post contains unsafe health misinformation.',
    );
    await user.click(screen.getByRole('button', { name: 'Remove content' }));
    const dialog = screen.getByRole('dialog', { name: 'Remove this content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm removal' }));

    expect(api.post).toHaveBeenCalledWith(
      '/admin/report-cases/post/post-1/decision',
      {
        decision: 'remove',
        reason: 'The post contains unsafe health misinformation.',
      },
    );
  });
});
