import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import { OverviewPage } from './OverviewPage';

const recentDecisions = Array.from({ length: 15 }, (_, index) => ({
  id: `audit-${index + 1}`,
  adminId: 'admin-1',
  adminEmail: 'alex@cyanzone.test',
  actionType: 'creator_request.approved',
  targetType: 'creator_request',
  targetId: `request-${index + 1}`,
  reason: `Decision reason ${index + 1}`,
  createdAt: `2026-07-${String(31 - index).padStart(2, '0')}T08:00:00.000Z`,
}));

describe('OverviewPage', () => {
  it('shows operational queues and 15 decisions in a scrollable panel', async () => {
    const api = {
      get: vi.fn().mockResolvedValue({
        pendingCreatorRequests: 8,
        pendingReportCases: 2,
        pendingAppeals: 3,
        recentDecisions,
      }),
      post: vi.fn(),
    } satisfies AdminApi;

    render(
      <MemoryRouter>
        <OverviewPage api={api} />
      </MemoryRouter>,
    );

    expect(await screen.findByRole('link', { name: /Creator Requests 8/ })).toHaveAttribute(
      'href',
      '/creator-requests',
    );
    expect(screen.getByRole('link', { name: /Report cases 2/ })).toBeVisible();
    expect(screen.getByRole('link', { name: /Appeals 3/ })).toBeVisible();
    expect(screen.getByText('Decision reason 1')).toBeVisible();
    expect(await screen.findAllByTestId('recent-decision')).toHaveLength(15);
    expect(screen.getByTestId('recent-decisions-scroll')).toHaveClass(
      'overflow-y-auto',
    );
    expect(screen.queryByText(/analytics/i)).not.toBeInTheDocument();
    expect(document.querySelector('canvas')).not.toBeInTheDocument();
  });
});
