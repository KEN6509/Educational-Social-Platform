import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { adminApi } from '../../lib/adminApi';
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
  categoryScores: { hate: 50 },
  evidence: ['Ambiguous phrase'],
  userReason: 'Needs a human check.',
  model: 'gemini-3.8-flash',
  status: 'pending' as const,
  decisionReason: null,
  decidedAt: null,
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
    vi.clearAllMocks();
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
});
