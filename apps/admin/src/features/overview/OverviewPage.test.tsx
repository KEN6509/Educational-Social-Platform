import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import { OverviewPage } from './OverviewPage';

describe('OverviewPage', () => {
  it('shows operational queue shortcuts and recent decisions without analytics charts', async () => {
    const api = {
      get: vi.fn().mockResolvedValue({
        pendingCreatorRequests: 8,
        pendingReportCases: 2,
        pendingAppeals: 3,
        recentDecisions: [
          {
            id: 'audit-1',
            adminId: 'admin-1',
            adminEmail: 'alex@cyanzone.test',
            actionType: 'creator_request.approved',
            targetType: 'creator_request',
            targetId: 'request-1',
            reason: 'Strong educational profile and original content.',
            createdAt: '2026-07-31T08:00:00.000Z',
          },
        ],
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
    expect(screen.getByText('Strong educational profile and original content.')).toBeVisible();
    expect(screen.queryByText(/analytics/i)).not.toBeInTheDocument();
    expect(document.querySelector('canvas')).not.toBeInTheDocument();
  });
});
