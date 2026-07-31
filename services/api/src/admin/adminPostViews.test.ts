import assert from 'node:assert/strict';
import test from 'node:test';

import { buildAdminPostDetail } from './adminPostViews.js';

test('maps post images in position order and nests approved replies', () => {
  const result = buildAdminPostDetail({
    post: {
      id: 'post-1',
      author_id: 'creator-1',
      title: 'Repair guide',
      content: 'Full guide',
      tags: ['Technology'],
      moderation_status: 'approved',
      published_at: '2026-07-31T00:00:00.000Z',
      created_at: '2026-07-30T00:00:00.000Z',
    },
    author: { id: 'creator-1', name: 'Ken', avatar_url: null },
    images: [
      {
        post_id: 'post-1',
        public_url: 'https://img/second.jpg',
        position: 2,
      },
      {
        post_id: 'post-1',
        public_url: 'https://img/first.jpg',
        position: 1,
      },
    ],
    comments: [
      {
        id: 'comment-1',
        post_id: 'post-1',
        author_id: 'member-1',
        parent_comment_id: null,
        content: 'Helpful',
        created_at: '2026-07-31T01:00:00.000Z',
      },
      {
        id: 'reply-1',
        post_id: 'post-1',
        author_id: 'creator-1',
        parent_comment_id: 'comment-1',
        content: 'Thank you',
        created_at: '2026-07-31T02:00:00.000Z',
      },
    ],
    profiles: [
      { id: 'member-1', name: 'Member', avatar_url: null },
      { id: 'creator-1', name: 'Ken', avatar_url: null },
    ],
    likeCounts: new Map([['comment-1', 4]]),
  });

  assert.deepEqual(
    result.images.map((image) => image.url),
    ['https://img/first.jpg', 'https://img/second.jpg'],
  );
  assert.equal(result.coverImageUrl, 'https://img/first.jpg');
  assert.equal(result.commentCount, 2);
  assert.equal(result.comments[0]?.replies[0]?.isCreator, true);
  assert.equal(result.comments[0]?.likeCount, 4);
});
