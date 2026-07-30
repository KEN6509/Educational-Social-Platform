import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type {
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
  status: 'open',
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
      description: 'Encourages unsafe sleep habits.',
      status: 'pending',
      createdAt: '2026-07-31T08:00:00.000Z',
      reviewedAt: null,
      resolutionNote: null,
    },
  ],
  recentDecisions: [],
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
      return detail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('ReportsPage', () => {
  it('renders grouped case counts, unique reporters, reasons, and visibility', async () => {
    const api = createApi();
    render(<ReportsPage api={api} />);

    expect(await screen.findByText('Why Sleep Matters')).toBeVisible();
    expect(await screen.findByText('7 unique reports')).toBeVisible();
    expect(screen.getByText('Harmful advice')).toBeVisible();
    expect(screen.getByText('5')).toBeVisible();
    expect(screen.getByText('Currently visible')).toBeVisible();
    expect(screen.getByText('1 case')).toBeVisible();
    expect(screen.queryByText('7 cases')).not.toBeInTheDocument();
  });

  it('confirms removal with a required administrator reason', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<ReportsPage api={api} />);
    await screen.findByText('7 unique reports');

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
