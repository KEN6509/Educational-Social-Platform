import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { AdminPortalLayout } from './AdminPortalLayout';

describe('AdminPortalLayout', () => {
  it('shows the complete route-aware casework navigation and queue counts', () => {
    render(
      <MemoryRouter initialEntries={['/creator-requests']}>
        <Routes>
          <Route
            element={
              <AdminPortalLayout
                counts={{ creatorRequests: 8, reports: 2, appeals: 3 }}
                email="alex@cyanzone.test"
                onSignOut={vi.fn()}
              />
            }
          >
            <Route path="/creator-requests" element={<p>Request desk</p>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByRole('link', { name: 'Overview' })).toBeVisible();
    expect(screen.getByRole('link', { name: 'Users' })).toBeVisible();
    expect(
      screen.getByRole('link', { name: /Creator Requests 8/ }),
    ).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('link', { name: /Reports 2/ })).toBeVisible();
    expect(screen.getByRole('link', { name: /Appeals 3/ })).toBeVisible();
    expect(
      screen.getByRole('link', { name: 'AI-Flagged Content' }),
    ).toHaveAttribute('href', '/ai-flagged');
    expect(screen.getByText('Request desk')).toBeVisible();
  });

  it('requires confirmation before signing out', async () => {
    const user = userEvent.setup();
    const onSignOut = vi.fn().mockResolvedValue(null);
    render(
      <MemoryRouter>
        <Routes>
          <Route
            element={
              <AdminPortalLayout
                counts={{ creatorRequests: 0, reports: 0, appeals: 0 }}
                email="alex@cyanzone.test"
                onSignOut={onSignOut}
              />
            }
          >
            <Route index element={<p>Overview</p>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    await user.click(screen.getByRole('button', { name: 'Log out' }));
    const dialog = screen.getByRole('dialog', {
      name: 'Log out of Admin Portal?',
    });
    expect(dialog).toBeVisible();
    expect(onSignOut).not.toHaveBeenCalled();

    await user.click(within(dialog).getByRole('button', { name: 'Log out' }));
    expect(onSignOut).toHaveBeenCalledOnce();
  });
});
