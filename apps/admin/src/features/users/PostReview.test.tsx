import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { AllPostsModal } from './AllPostsModal';
import { PostDetailModal } from './PostDetailModal';
import { RecentPostsCarousel } from './RecentPostsCarousel';

const posts = Array.from({ length: 8 }, (_, index) => ({
  id: `post-${index + 1}`,
  title: index === 0 ? 'Repair guide' : `Published post ${index + 1}`,
  content:
    index === 0
      ? 'Full untruncated post content'
      : `Complete post content ${index + 1}`,
  tags: ['Technology', 'Guide'],
  moderationStatus: 'approved',
  publishedAt: `2026-07-${String(31 - index).padStart(2, '0')}T08:00:00.000Z`,
  createdAt: `2026-07-${String(30 - index).padStart(2, '0')}T08:00:00.000Z`,
  coverImageUrl: `https://img.test/post-${index + 1}.jpg`,
  imageCount: 2,
  commentCount: 2,
}));

const detail = {
  ...posts[0]!,
  authorId: 'creator-1',
  authorName: 'Ken Chan',
  authorAvatarUrl: 'https://img.test/creator.jpg',
  images: [
    { url: 'https://img.test/post-1.jpg', position: 1 },
    { url: 'https://img.test/post-1-second.jpg', position: 2 },
  ],
  comments: [
    {
      id: 'comment-1',
      authorId: 'member-1',
      authorName: 'Helpful Member',
      authorAvatarUrl: null,
      isCreator: false,
      content: 'Helpful comment',
      createdAt: '2026-07-31T09:00:00.000Z',
      likeCount: 4,
      replies: [
        {
          id: 'reply-1',
          authorId: 'creator-1',
          authorName: 'Ken Chan',
          authorAvatarUrl: 'https://img.test/creator.jpg',
          isCreator: true,
          content: 'Creator reply',
          createdAt: '2026-07-31T10:00:00.000Z',
          likeCount: 2,
          replies: [],
        },
      ],
    },
  ],
};

describe('administrator post review UI', () => {
  it('limits the recent carousel to five posts and scrolls one card', async () => {
    const user = userEvent.setup();
    const scrollBy = vi.fn();
    Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
      configurable: true,
      value: 280,
    });
    HTMLElement.prototype.scrollBy = scrollBy;

    render(
      <RecentPostsCarousel onOpenPost={vi.fn()} posts={posts} />,
    );

    expect(
      screen.getAllByRole('button', { name: /Open post/ }),
    ).toHaveLength(5);
    expect(
      screen.getByRole('button', { name: 'Previous posts' }),
    ).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Next posts' }));
    expect(scrollBy).toHaveBeenCalledWith({
      behavior: 'smooth',
      left: 296,
    });
    expect(
      screen.getByRole('button', { name: 'Previous posts' }),
    ).toBeEnabled();
  });

  it('shows every published post in a filter-free four-column modal', () => {
    render(
      <AllPostsModal
        isOpen
        onClose={vi.fn()}
        onOpenPost={vi.fn()}
        posts={posts}
      />,
    );

    const dialog = screen.getByRole('dialog', {
      name: 'All published posts',
    });
    expect(within(dialog).getAllByTestId('all-post-card')).toHaveLength(8);
    expect(within(dialog).getByTestId('all-posts-grid')).toHaveClass(
      'xl:grid-cols-4',
    );
    expect(screen.queryByRole('searchbox')).not.toBeInTheDocument();
  });

  it('shows all post fields, media, and nested comments in one detail modal', async () => {
    const user = userEvent.setup();
    render(
      <PostDetailModal
        isOpen
        onClose={vi.fn()}
        post={detail}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: 'Repair guide' });
    expect(
      within(dialog).getByText('Full untruncated post content'),
    ).toBeVisible();
    expect(within(dialog).getByText('Technology')).toBeVisible();
    expect(within(dialog).getByText('Approved')).toBeVisible();
    expect(within(dialog).getByText('Comments (2)')).toBeVisible();
    expect(within(dialog).getByText('Helpful comment')).toBeVisible();
    expect(within(dialog).getByText('Creator reply')).toBeVisible();
    expect(within(dialog).getByText('Creator')).toBeVisible();

    await user.click(
      within(dialog).getByRole('button', { name: 'Show image 2' }),
    );
    expect(
      within(dialog).getByRole('img', { name: 'Repair guide image 2' }),
    ).toHaveAttribute('src', 'https://img.test/post-1-second.jpg');
  });
});
