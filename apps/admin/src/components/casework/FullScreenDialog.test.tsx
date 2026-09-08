import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { FullScreenDialog } from './FullScreenDialog';

describe('FullScreenDialog', () => {
  it('closes with Escape, traps focus, and restores the origin', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    const { rerender } = render(
      <>
        <button type="button">Origin</button>
        <FullScreenDialog
          isOpen={false}
          label="All published posts"
          onClose={onClose}
        >
          <button type="button">First</button>
          <button type="button">Last</button>
        </FullScreenDialog>
      </>,
    );

    const origin = screen.getByRole('button', { name: 'Origin' });
    origin.focus();
    rerender(
      <>
        <button type="button">Origin</button>
        <FullScreenDialog
          isOpen
          label="All published posts"
          onClose={onClose}
        >
          <button type="button">First</button>
          <button type="button">Last</button>
        </FullScreenDialog>
      </>,
    );

    const dialog = screen.getByRole('dialog', {
      name: 'All published posts',
    });
    await waitFor(() => expect(dialog).toHaveFocus());

    const close = screen.getByRole('button', { name: 'Close' });
    const last = screen.getByRole('button', { name: 'Last' });
    last.focus();
    await user.tab();
    expect(close).toHaveFocus();
    await user.tab({ shift: true });
    expect(last).toHaveFocus();

    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalledOnce();
    rerender(
      <>
        <button type="button">Origin</button>
        <FullScreenDialog
          isOpen={false}
          label="All published posts"
          onClose={onClose}
        >
          <button type="button">First</button>
          <button type="button">Last</button>
        </FullScreenDialog>
      </>,
    );
    expect(origin).toHaveFocus();
  });
});
