import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { AdminApiError, adminApi } from '../../lib/adminApi';
import { AiFlaggedContentPage } from './AiFlaggedContentPage';

vi.mock('../../lib/adminApi', async () => {
  const actual = await vi.importActual<typeof import('../../lib/adminApi')>('../../lib/adminApi');
  return {
    ...actual,
    adminApi: {
      get: vi.fn(),
      post: vi.fn(),
    },
  };
});

const pendingCase = {
  id: 'case-1',
  targetType: 'post' as const,
  targetId: 'post-1',
  moderationRevision: 1,
  authorName: 'Member One',
  authorEmail: 'member@example.test',
  submittedAt: '2026-09-06T12:00:00.000Z',
  title: 'A reviewed post',
  content: 'Content under review',
  imageUrls: ['https://cdn.example.test/image.jpg'],
  riskScore: 50,
  evidence: ['Ambiguous phrase'],
  userReason: 'Needs a human check.',
  model: 'gemini-3.8-flash',
  status: 'pending' as const,
  decisionReason: null,
  decidedAt: null,
};

const approvedCase = {
  ...pendingCase,
  id: 'case-2',
  targetId: 'post-2',
  title: 'Administrator approved post',
  status: 'approved' as const,
};

describe('AiFlaggedContentPage', () => {
  beforeEach(() => {
    vi.mocked(adminApi.get).mockResolvedValue({
      items: [pendingCase],
      page: 1,
      pageSize: 20,
      total: 1,
    });
    vi.mocked(adminApi.post).mockResolvedValue(undefined);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it('adds newly pending cases to the open queue on its refresh interval', async () => {
    vi.useFakeTimers();
    vi.mocked(adminApi.get).mockReset()
      .mockResolvedValueOnce({ items: [], page: 1, pageSize: 20, total: 0 })
      .mockResolvedValue({ items: [pendingCase], page: 1, pageSize: 20, total: 1 });

    render(<AiFlaggedContentPage />);
    await act(async () => { await Promise.resolve(); });
    expect(screen.getByText('No pending cases.')).toBeVisible();

    await act(async () => { await vi.advanceTimersByTimeAsync(15_000); });
    expect(screen.getAllByText('A reviewed post')[0]).toBeVisible();
    expect(adminApi.get).toHaveBeenCalledTimes(2);
  });

  it('refreshes on return to the visible tab and stops polling after unmount', async () => {
    vi.useFakeTimers();
    const view = render(<AiFlaggedContentPage />);
    await act(async () => { await Promise.resolve(); });
    expect(adminApi.get).toHaveBeenCalledTimes(1);

    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'hidden' });
    await act(async () => { await vi.advanceTimersByTimeAsync(15_000); });
    expect(adminApi.get).toHaveBeenCalledTimes(1);

    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'visible' });
    await act(async () => { document.dispatchEvent(new Event('visibilitychange')); });
    expect(adminApi.get).toHaveBeenCalledTimes(2);
    view.unmount();
    await act(async () => { await vi.advanceTimersByTimeAsync(30_000); });
    expect(adminApi.get).toHaveBeenCalledTimes(2);
    Reflect.deleteProperty(document, 'visibilityState');
  });

  it('does not change the decision target when an in-flight refresh finishes', async () => {
    const user = userEvent.setup();
    let resolveRefresh!: (value: unknown) => void;
    const otherCase = { ...pendingCase, id: 'case-other', title: 'Other pending post' };
    vi.mocked(adminApi.get).mockReset()
      .mockResolvedValueOnce({ items: [pendingCase], page: 1, pageSize: 20, total: 1 })
      .mockImplementationOnce(() => new Promise((resolve) => { resolveRefresh = resolve; }))
      .mockResolvedValue({ items: [pendingCase], page: 1, pageSize: 20, total: 1 });

    render(<AiFlaggedContentPage />);
    await screen.findByRole('button', { name: 'Approve content' });
    act(() => { window.dispatchEvent(new Event('focus')); });
    await waitFor(() => expect(adminApi.get).toHaveBeenCalledTimes(2));
    await user.click(screen.getByRole('button', { name: 'Approve content' }));
    await act(async () => {
      resolveRefresh({ items: [otherCase], page: 1, pageSize: 20, total: 1 });
    });

    expect(screen.queryAllByText('Other pending post')).toHaveLength(0);
    const dialog = screen.getByRole('dialog', { name: 'Approve content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));
    expect(adminApi.post).toHaveBeenCalledWith(
      '/admin/moderation-cases/case-1/decision',
      { decision: 'approved', reason: '' },
    );
  });

  it('loads genuine cases from the moderation API with evidence and images', async () => {
    render(<AiFlaggedContentPage />);

    expect((await screen.findAllByText('A reviewed post'))[0]).toBeVisible();
    expect(screen.getByText('Ambiguous phrase')).toBeVisible();
    expect(screen.getByText(/gemini-3\.8-flash/)).toBeVisible();
    expect(screen.getByAltText('Moderated post attachment')).toBeVisible();
    expect(adminApi.get).toHaveBeenCalledWith('/admin/moderation-cases', {
      status: 'pending',
      page: 1,
      pageSize: 20,
    });
  });

  it('requires confirmation before sending an API decision and reloads the queue', async () => {
    const user = userEvent.setup();
    render(<AiFlaggedContentPage />);

    await user.click(await screen.findByRole('button', { name: 'Approve content' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));

    expect(adminApi.post).toHaveBeenCalledWith(
      '/admin/moderation-cases/case-1/decision',
      { decision: 'approved', reason: '' },
    );
    expect(await screen.findByText('Decision saved.')).toBeVisible();
    expect(adminApi.get).toHaveBeenCalledTimes(2);
  });

  it('requires a reason before rejecting content', async () => {
    const user = userEvent.setup();
    render(<AiFlaggedContentPage />);

    await user.click(await screen.findByRole('button', { name: 'Reject content' }));
    expect(screen.queryByRole('dialog', { name: 'Reject content?' })).not.toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent(
      'Enter a reason between 10 and 500 characters before choosing "Reject content".',
    );
  });

  it('shows a failed decision inside the confirmation dialog and allows retry', async () => {
    const user = userEvent.setup();
    vi.mocked(adminApi.post).mockRejectedValueOnce(
      new AdminApiError('server', 'Unable to complete the administrator request.', 500),
    );
    render(<AiFlaggedContentPage />);

    await user.click(await screen.findByRole('button', { name: 'Approve content' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve content?' });
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));

    expect(await within(dialog).findByRole('alert')).toHaveTextContent(
      'Unable to complete the administrator request.',
    );
    expect(within(dialog).getByRole('button', { name: 'Confirm approval' })).toBeEnabled();
    expect(adminApi.post).toHaveBeenCalledTimes(1);
  });

  it('ignores an older tab response after the administrator changes tabs', async () => {
    const user = userEvent.setup();
    let resolvePending!: (value: unknown) => void;
    let resolveApproved!: (value: unknown) => void;
    vi.mocked(adminApi.get).mockReset()
      .mockImplementationOnce(() => new Promise((resolve) => { resolvePending = resolve; }))
      .mockImplementationOnce(() => new Promise((resolve) => { resolveApproved = resolve; }));

    render(<AiFlaggedContentPage />);
    await user.click(screen.getByRole('tab', { name: 'Approved' }));
    await waitFor(() => expect(adminApi.get).toHaveBeenCalledTimes(2));
    resolveApproved({ items: [approvedCase], page: 1, pageSize: 20, total: 1 });
    expect((await screen.findAllByText('Administrator approved post'))[0]).toBeVisible();
    resolvePending({ items: [pendingCase], page: 1, pageSize: 20, total: 1 });
    await waitFor(() => expect(screen.queryByText('A reviewed post')).not.toBeInTheDocument());
  });

  it('keeps cached rows visible when their background refresh fails', async () => {
    const user = userEvent.setup();
    vi.mocked(adminApi.get).mockReset()
      .mockResolvedValueOnce({ items: [pendingCase], page: 1, pageSize: 20, total: 1 })
      .mockResolvedValueOnce({ items: [approvedCase], page: 1, pageSize: 20, total: 1 })
      .mockRejectedValueOnce(new AdminApiError('server', 'Unable to refresh moderation cases.', 503));

    render(<AiFlaggedContentPage />);
    expect((await screen.findAllByText('A reviewed post'))[0]).toBeVisible();
    await user.click(screen.getByRole('tab', { name: 'Approved' }));
    expect((await screen.findAllByText('Administrator approved post'))[0]).toBeVisible();
    await user.click(screen.getByRole('tab', { name: 'Pending' }));
    expect((await screen.findAllByText('A reviewed post'))[0]).toBeVisible();
    expect(await screen.findByRole('alert')).toHaveTextContent('Unable to refresh moderation cases.');
  });
});
