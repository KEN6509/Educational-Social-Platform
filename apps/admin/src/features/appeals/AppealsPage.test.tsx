import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import type { AdminApi } from '../../lib/adminApi';
import type {
  AppealDetailView,
  AppealSummaryView,
  PageResult,
} from '../../types/admin';
import { AppealsPage } from './AppealsPage';

const summary: AppealSummaryView = {
  id: 'appeal-1',
  postId: 'post-1',
  userId: 'user-1',
  userName: 'Aisha Khan',
  userEmail: 'aisha@cyanzone.test',
  postTitle: 'Understanding Exam Stress',
  reason: 'The post discusses warning signs for education, not self-harm advice.',
  status: 'pending',
  createdAt: '2026-07-31T09:00:00.000Z',
  reviewedAt: null,
};

const detail: AppealDetailView = {
  ...summary,
  postContent: 'Some students describe feeling hopeless during exam season.',
  moderationStatus: 'rejected',
  originalModerationReason: 'Potentially unsafe mental-health wording.',
  originalReviewedAt: '2026-07-30T10:00:00.000Z',
  aiToxicityScore: null,
  adminNote: null,
  reviewedBy: null,
  recentDecisions: [],
};

function createApi() {
  return {
    get: vi.fn(async (path: string) => {
      if (path === '/admin/appeals') {
        return {
          items: [summary],
          page: 1,
          pageSize: 20,
          total: 1,
        } satisfies PageResult<AppealSummaryView>;
      }
      return detail;
    }),
    post: vi.fn().mockResolvedValue(undefined),
  } as unknown as AdminApi;
}

describe('AppealsPage', () => {
  it('separates rejected content, original evidence, and the appeal reason', async () => {
    const api = createApi();
    render(<AppealsPage api={api} />);

    expect(await screen.findByText('Understanding Exam Stress')).toBeVisible();
    expect(await screen.findByText('Rejected content')).toBeVisible();
    expect(screen.getByText('Potentially unsafe mental-health wording.')).toBeVisible();
    expect(
      screen.getByText(
        'The post discusses warning signs for education, not self-harm advice.',
      ),
    ).toBeVisible();
    expect(screen.getByRole('tab', { name: 'Approved' })).toBeVisible();
    expect(screen.getByRole('tab', { name: 'Rejected' })).toBeVisible();
  });

  it('confirms approval and explains that content will be republished', async () => {
    const user = userEvent.setup();
    const api = createApi();
    render(<AppealsPage api={api} />);
    await screen.findByText('Rejected content');

    await user.type(
      screen.getByLabelText(/Decision reason/),
      'The educational context is clear and safe for publication.',
    );
    await user.click(screen.getByRole('button', { name: 'Approve appeal' }));
    const dialog = screen.getByRole('dialog', { name: 'Approve this appeal?' });
    expect(
      within(dialog).getByText(/republished/i),
    ).toBeVisible();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm approval' }));

    expect(api.post).toHaveBeenCalledWith('/admin/appeals/appeal-1/decision', {
      decision: 'approved',
      reason: 'The educational context is clear and safe for publication.',
    });
  });
});
