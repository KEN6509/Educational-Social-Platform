import type {
  AdminCommentView,
  AdminPostDetailView,
  PostSummaryView,
} from './adminTypes.js';

export type AdminPostRow = {
  id: string;
  author_id: string;
  title: string | null;
  content: string | null;
  tags: unknown;
  moderation_status: string;
  published_at: string | null;
  created_at: string;
};

export type AdminPostImageRow = {
  post_id: string;
  public_url: string | null;
  position: number;
};

export type AdminPostCommentRow = {
  id: string;
  post_id: string;
  author_id: string;
  parent_comment_id: string | null;
  content: string;
  created_at: string;
};

export type AdminPostProfileRow = {
  id: string;
  name: string;
  avatar_url: string | null;
};

type SummaryInput = {
  post: AdminPostRow;
  images: AdminPostImageRow[];
  comments: Array<Pick<AdminPostCommentRow, 'id' | 'post_id'>>;
};

type DetailInput = Omit<SummaryInput, 'comments'> & {
  author: AdminPostProfileRow | null;
  comments: AdminPostCommentRow[];
  profiles: AdminPostProfileRow[];
  likeCounts: ReadonlyMap<string, number>;
};

export function buildAdminPostSummary({
  post,
  images,
  comments,
}: SummaryInput): PostSummaryView {
  const orderedImages = mapOrderedImages(images);

  return {
    id: post.id,
    title: post.title ?? '',
    content: post.content ?? '',
    tags: Array.isArray(post.tags)
      ? post.tags.filter((tag): tag is string => typeof tag === 'string')
      : [],
    moderationStatus: post.moderation_status,
    publishedAt: post.published_at,
    createdAt: post.created_at,
    coverImageUrl: orderedImages[0]?.url ?? null,
    imageCount: orderedImages.length,
    commentCount: comments.length,
  };
}

export function buildAdminPostDetail(input: DetailInput): AdminPostDetailView {
  const summary = buildAdminPostSummary(input);
  const profileById = new Map(
    input.profiles.map((profile) => [profile.id, profile]),
  );
  if (input.author) {
    profileById.set(input.author.id, input.author);
  }

  const commentById = new Map<string, AdminCommentView>();
  const orderedComments = [...input.comments].sort(
    (left, right) =>
      left.created_at.localeCompare(right.created_at) ||
      left.id.localeCompare(right.id),
  );

  for (const comment of orderedComments) {
    const profile = profileById.get(comment.author_id);
    commentById.set(comment.id, {
      id: comment.id,
      authorId: comment.author_id,
      authorName: profile?.name ?? 'CyanZone member',
      authorAvatarUrl: profile?.avatar_url ?? null,
      isCreator: comment.author_id === input.post.author_id,
      content: comment.content,
      createdAt: comment.created_at,
      likeCount: input.likeCounts.get(comment.id) ?? 0,
      replies: [],
    });
  }

  const comments: AdminCommentView[] = [];
  for (const comment of orderedComments) {
    const view = commentById.get(comment.id)!;
    const parent = comment.parent_comment_id
      ? commentById.get(comment.parent_comment_id)
      : undefined;
    if (parent) {
      parent.replies.push(view);
    } else {
      comments.push(view);
    }
  }

  return {
    ...summary,
    authorId: input.post.author_id,
    authorName: input.author?.name ?? 'CyanZone member',
    authorAvatarUrl: input.author?.avatar_url ?? null,
    images: mapOrderedImages(input.images),
    comments,
  };
}

function mapOrderedImages(images: AdminPostImageRow[]) {
  return images
    .filter(
      (image): image is AdminPostImageRow & { public_url: string } =>
        typeof image.public_url === 'string' &&
        image.public_url.trim().length > 0,
    )
    .sort(
      (left, right) =>
        left.position - right.position ||
        left.public_url.localeCompare(right.public_url),
    )
    .map((image) => ({
      url: image.public_url,
      position: image.position,
    }));
}
