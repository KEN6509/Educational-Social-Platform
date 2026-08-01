import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { aiFlaggedMockData } from './aiFlaggedMockData';
import { AiFlaggedContentPage } from './AiFlaggedContentPage';

describe('AiFlaggedContentPage', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('presents post and comment moderation without implementation disclaimers', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    render(<AiFlaggedContentPage />);

    expect(aiFlaggedMockData).toHaveLength(6);
    expect(
      aiFlaggedMockData.every(
        (item) => item.riskScore >= 0.4 && item.riskScore <= 0.6,
      ),
    ).toBe(true);
    expect(await screen.findByText('Post')).toBeVisible();
    expect(screen.getAllByText(/Comment/).length).toBeGreaterThan(0);
    expect(document.body.textContent).not.toMatch(
      /mock|preview|temporary|future|deferred|not implemented|not connected|saved locally/i,
    );
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('requires confirmation before changing moderation status', async () => {
    const user = userEvent.setup();
    const { unmount } = render(<AiFlaggedContentPage />);

    expect(screen.getByRole('tab', { name: 'Pending' })).toHaveTextContent(
      /^Pending$/,
    );
    expect(screen.getByRole('tab', { name: 'Approved' })).toHaveTextContent(
      /^Approved$/,
    );
    expect(screen.getByRole('tab', { name: 'Rejected' })).toHaveTextContent(
      /^Rejected$/,
    );
    await user.click(screen.getByRole('button', { name: 'Approve content' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));
    expect(await screen.findByText('Decision saved.')).toBeVisible();

    unmount();
    render(<AiFlaggedContentPage />);
    expect(screen.queryByText('Decision saved.')).not.toBeInTheDocument();
    expect(screen.getByRole('tab', { name: /Pending/ })).toHaveAttribute(
      'aria-selected',
      'true',
    );
  });

  it('requires a reason before rejecting content', async () => {
    const user = userEvent.setup();
    render(<AiFlaggedContentPage />);

    await user.click(screen.getByRole('button', { name: 'Reject content' }));
    expect(
      screen.queryByRole('dialog', { name: 'Reject content?' }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent(
      'Enter a reason between 10 and 500 characters before choosing "Reject content".',
    );
  });
});
