import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { aiFlaggedMockData } from './aiFlaggedMockData';
import { AiFlaggedContentPage } from './AiFlaggedContentPage';

describe('AiFlaggedContentPage', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('is an isolated post/comment preview with bounded mock scores', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    render(<AiFlaggedContentPage />);

    expect(
      screen.getByText('Preview data - Gemini integration is not connected.'),
    ).toBeVisible();
    expect(aiFlaggedMockData).toHaveLength(6);
    expect(
      aiFlaggedMockData.every(
        (item) => item.riskScore >= 0.4 && item.riskScore <= 0.6,
      ),
    ).toBe(true);
    expect(await screen.findByText('Post')).toBeVisible();
    expect(screen.getAllByText(/Comment/).length).toBeGreaterThan(0);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('requires confirmation, changes local status, and resets on a new instance', async () => {
    const user = userEvent.setup();
    const { unmount } = render(<AiFlaggedContentPage />);

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'The context is educational and does not violate policy.',
    );
    await user.click(screen.getByRole('button', { name: 'Approve content' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve preview content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));
    expect(await screen.findByText('Preview decision saved locally.')).toBeVisible();

    unmount();
    render(<AiFlaggedContentPage />);
    expect(screen.queryByText('Preview decision saved locally.')).not.toBeInTheDocument();
    expect(screen.getByRole('tab', { name: /Pending/ })).toHaveAttribute(
      'aria-selected',
      'true',
    );
  });
});
