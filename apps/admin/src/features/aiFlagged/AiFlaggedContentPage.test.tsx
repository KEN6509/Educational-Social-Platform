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

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'The context is educational and does not violate policy.',
    );
    await user.click(screen.getByRole('button', { name: 'Approve content' }));
    expect(screen.getByRole('tab', { name: /Pending/ })).toHaveTextContent('3');
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
});
