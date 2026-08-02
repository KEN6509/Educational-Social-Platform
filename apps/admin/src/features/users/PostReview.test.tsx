import { fireEvent, render, screen, within } from '@testing-library/react';
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
  it('limits the recent carousel to five posts and shows controls only on overflow', async () => {
    const user = userEvent.setup();
    const scrollBy = vi.fn();
    Object.defineProperty(HTMLElement.prototype, 'scrollWidth', {
      configurable: true,
      value: 1500,
    });
    Object.defineProperty(HTMLElement.prototype, 'clientWidth', {
      configurable: true,
      value: 600,
    });
    HTMLElement.prototype.scrollBy = scrollBy;

    render(
      <RecentPostsCarousel onOpenPost={vi.fn()} posts={posts} />,
    );

    expect(
      screen.getAllByRole('button', { name: /Open post/ }),
    ).toHaveLength(5);
    const firstCard = screen.getByRole('button', {
      name: 'Open post Repair guide',
    });
    expect(firstCard).toHaveClass(
      'flex',
      'flex-col',
      'hover:-translate-y-0.5',
    );
    expect(screen.getByTestId('recent-post-media-post-1')).toHaveClass(
      'h-28',
      'w-full',
      'shrink-0',
      'overflow-hidden',
    );
    expect(
      document.querySelector('img[src="https://img.test/post-1.jpg"]'),
    ).toHaveClass(
      'block',
      'h-full',
      'w-full',
      'object-cover',
    );
    expect(screen.getByTestId('recent-posts-rail')).toHaveClass('pt-2');
    expect(
      screen.getByRole('button', { name: 'Previous posts' }),
    ).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Next posts' }));
    expect(scrollBy).toHaveBeenCalledWith({
      behavior: 'smooth',
      left: 296,
    });
    const rail = screen.getByTestId('recent-posts-rail');
    Object.defineProperty(rail, 'scrollLeft', {
      configurable: true,
      value: 296,
    });
    fireEvent.scroll(rail);
    expect(
      screen.getByRole('button', { name: 'Previous posts' }),
    ).toBeEnabled();
  });

  it('hides carousel controls when all recent posts fit', () => {
    Object.defineProperty(HTMLElement.prototype, 'scrollWidth', {
      configurable: true,
      value: 600,
    });
    Object.defineProperty(HTMLElement.prototype, 'clientWidth', {
      configurable: true,
      value: 600,
    });

    render(<RecentPostsCarousel onOpenPost={vi.fn()} posts={posts} />);

    expect(screen.queryByRole('button', { name: 'Previous posts' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Next posts' })).not.toBeInTheDocument();
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
    expect(within(dialog).getAllByTestId('all-post-card')[0]).toHaveClass(
      'flex',
      'flex-col',
    );
    expect(
      within(dialog).getByTestId('all-post-media-post-1'),
    ).toHaveClass('block', 'w-full', 'overflow-hidden');
    expect(
      within(dialog).getByTestId('all-post-image-post-1'),
    ).toHaveClass('block', 'h-full', 'w-full', 'object-cover');
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
    expect(
      within(dialog).getByRole('img', { name: 'Repair guide image 1' }),
    ).toHaveClass(
      'absolute',
      'inset-0',
      'h-full',
      'w-full',
      'object-contain',
    );
    expect(within(dialog).getByTestId('post-media-stage')).toHaveClass(
      'relative',
      'overflow-hidden',
      'bg-slate-900',
    );
    expect(
      within(dialog).getByRole('button', { name: 'Previous image' }),
    ).toBeDisabled();
    expect(
      within(dialog).getByRole('button', { name: 'Next image' }),
    ).toBeEnabled();

    await user.click(
      within(dialog).getByRole('button', { name: 'Next image' }),
    );
    expect(
      within(dialog).getByRole('img', { name: 'Repair guide image 2' }),
    ).toHaveAttribute('src', 'https://img.test/post-1-second.jpg');
    expect(
      within(dialog).getByRole('button', { name: 'Show image 2' }),
    ).toHaveAttribute('aria-current', 'true');
  });

  it('places Back to all posts in the modal header instead of the media section', () => {
    render(
      <PostDetailModal
        isOpen
        onBack={vi.fn()}
        onClose={vi.fn()}
        post={detail}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: 'Repair guide' });
    const backButton = within(dialog).getByRole('button', {
      name: 'Back to all posts',
    });
    const header = backButton.closest('header');

    expect(header).not.toBeNull();
    expect(within(header!).queryByText('Repair guide')).not.toBeInTheDocument();
    expect(
      within(dialog).getByTestId('post-media-stage'),
    ).not.toContainElement(backButton);
  });
});
