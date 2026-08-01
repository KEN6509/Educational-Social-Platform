import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { AsyncState } from './AsyncState';
import { CaseworkList } from './CaseworkList';
import { CaseworkTabs } from './CaseworkTabs';
import { DecisionDialog } from './DecisionDialog';
import { DecisionPanel } from './DecisionPanel';
import { StatusBadge } from './StatusBadge';

describe('casework components', () => {
  it('supports accessible tabs and selectable queue rows', async () => {
    const user = userEvent.setup();
    const onTabChange = vi.fn();
    const onSelect = vi.fn();
    render(
      <>
        <CaseworkTabs
          activeId="pending"
          items={[
            { id: 'pending', label: 'Pending', count: 8 },
            { id: 'approved', label: 'Approved', count: 24 },
          ]}
          onChange={onTabChange}
        />
        <CaseworkList
          items={[
            { id: '1', title: 'Lena Park', subtitle: 'Science & Curiosity' },
            { id: '2', title: 'Marcus Rivera', subtitle: 'History in Focus' },
          ]}
          selectedId="1"
          onSelect={onSelect}
        />
      </>,
    );

    expect(screen.getByRole('tab', { name: /Pending 8/ })).toHaveAttribute(
      'aria-selected',
      'true',
    );
    await user.click(screen.getByRole('tab', { name: /Approved 24/ }));
    expect(onTabChange).toHaveBeenCalledWith('approved');

    expect(screen.getByRole('button', { name: /Lena Park/ })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    await user.click(screen.getByRole('button', { name: /Marcus Rivera/ }));
    expect(onSelect).toHaveBeenCalledWith('2');
  });

  it('renders loading, empty, error, and retry states', async () => {
    const user = userEvent.setup();
    const retry = vi.fn();
    const { rerender } = render(<AsyncState state="loading" />);
    expect(screen.getByText('Loading casework…')).toBeVisible();

    rerender(<AsyncState state="empty" emptyMessage="No pending cases." />);
    expect(screen.getByText('No pending cases.')).toBeVisible();

    rerender(
      <AsyncState
        state="error"
        errorMessage="Cases could not be loaded."
        onRetry={retry}
      />,
    );
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(retry).toHaveBeenCalledOnce();
  });

  it('allows a blank optional reason but validates every supplied reason', async () => {
    const user = userEvent.setup();
    const onReasonChange = vi.fn();
    const onPrimary = vi.fn();
    const onDanger = vi.fn();
    const { rerender } = render(
      <DecisionPanel
        dangerLabel="Remove content"
        dangerRequiresReason
        reason=""
        onReasonChange={onReasonChange}
        primaryLabel="Retain content"
        primaryRequiresReason={false}
        isSubmitting={false}
        onPrimary={onPrimary}
        onDanger={onDanger}
      />,
    );

    await user.click(screen.getByRole('button', { name: 'Retain content' }));
    expect(onPrimary).toHaveBeenCalledOnce();

    rerender(
      <DecisionPanel
        dangerLabel="Remove content"
        dangerRequiresReason
        reason="short"
        onReasonChange={onReasonChange}
        primaryLabel="Retain content"
        primaryRequiresReason={false}
        isSubmitting={false}
        onPrimary={onPrimary}
        onDanger={onDanger}
      />,
    );

    await user.click(screen.getByRole('button', { name: 'Retain content' }));
    expect(onPrimary).toHaveBeenCalledOnce();
    expect(screen.getByRole('alert')).toBeVisible();

    await user.click(screen.getByRole('button', { name: 'Remove content' }));
    expect(onDanger).not.toHaveBeenCalled();
    expect(screen.getByRole('alert')).toHaveTextContent(
      'Enter a reason between 10 and 500 characters before choosing "Remove content".',
    );
    expect(screen.getByLabelText(/Decision reason/)).toHaveFocus();
  });

  it('requires a valid reason for both actions by default', async () => {
    const user = userEvent.setup();
    const onPrimary = vi.fn();
    const onDanger = vi.fn();

    render(
      <DecisionPanel
        dangerLabel="Reject appeal"
        isSubmitting={false}
        onDanger={onDanger}
        onPrimary={onPrimary}
        onReasonChange={vi.fn()}
        primaryLabel="Approve appeal"
        reason="short"
      />,
    );

    await user.click(screen.getByRole('button', { name: 'Approve appeal' }));
    expect(onPrimary).not.toHaveBeenCalled();
    expect(screen.getByRole('alert')).toBeVisible();

    await user.click(screen.getByRole('button', { name: 'Reject appeal' }));
    expect(onDanger).not.toHaveBeenCalled();
  });

  it('describes consequences and only closes an idle confirmation with Escape', async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();
    const onConfirm = vi.fn();
    const { rerender } = render(
      <DecisionDialog
        isOpen
        title="Approve this request?"
        consequence="The requester will become a content creator."
        confirmLabel="Confirm approval"
        isSubmitting={false}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );

    expect(
      screen.getByText('The requester will become a content creator.'),
    ).toBeVisible();
    await user.keyboard('{Escape}');
    expect(onCancel).toHaveBeenCalledOnce();

    onCancel.mockClear();
    rerender(
      <DecisionDialog
        isOpen
        title="Approve this request?"
        consequence="The requester will become a content creator."
        confirmLabel="Confirm approval"
        isSubmitting
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );
    await user.keyboard('{Escape}');
    expect(onCancel).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Confirming…' })).toBeDisabled();
  });

  it('maps workflow statuses to readable badges', () => {
    render(
      <>
        <StatusBadge status="pending" />
        <StatusBadge status="approved" />
        <StatusBadge status="suspended" />
      </>,
    );
    expect(screen.getByText('Pending')).toBeVisible();
    expect(screen.getByText('Approved')).toBeVisible();
    expect(screen.getByText('Suspended')).toBeVisible();
  });
});
