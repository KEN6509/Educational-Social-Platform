import { ArrowLeft, Heart, ImageOff, UserRound } from 'lucide-react';
import { useEffect, useState } from 'react';

import { FullScreenDialog } from '../../components/casework/FullScreenDialog';
import { StatusBadge } from '../../components/casework/StatusBadge';
import type {
  AdminCommentView,
  AdminPostDetailView,
} from '../../types/admin';

type Props = {
  isOpen: boolean;
  post: AdminPostDetailView | null;
  onClose: () => void;
  onBack?: () => void;
};

export function PostDetailModal({ isOpen, post, onClose, onBack }: Props) {
  const [selectedImage, setSelectedImage] = useState(0);

  useEffect(() => {
    setSelectedImage(0);
  }, [post?.id]);

  if (!post) return null;

  const image = post.images[selectedImage];

  return (
    <FullScreenDialog isOpen={isOpen} label={post.title} onClose={onClose}>
      <div className="grid h-full min-h-0 lg:grid-cols-[minmax(0,58%)_minmax(22rem,42%)]">
        <section className="flex min-h-[20rem] flex-col bg-slate-100 p-4 sm:p-6 lg:min-h-0">
          {onBack ? (
            <button
              className="mb-4 inline-flex w-fit items-center gap-2 rounded-lg bg-white px-3 py-2 text-sm font-bold text-slate-700 shadow-sm transition hover:text-cyan-700 focus:outline-none focus:ring-4 focus:ring-cyan-100"
              onClick={onBack}
              type="button"
            >
              <ArrowLeft className="h-4 w-4" aria-hidden="true" />
              Back to all posts
            </button>
          ) : null}

          <div className="grid min-h-0 flex-1 place-items-center overflow-hidden rounded-xl bg-white shadow-sm">
            {image ? (
              <img
                alt={`${post.title} image ${selectedImage + 1}`}
                className="h-full max-h-full w-full object-contain"
                src={image.url}
              />
            ) : (
              <div className="flex flex-col items-center gap-3 text-slate-400">
                <ImageOff className="h-12 w-12" aria-hidden="true" />
                <p className="text-sm font-bold">This post has no images.</p>
              </div>
            )}
          </div>

          {post.images.length > 1 ? (
            <div className="mt-4 flex shrink-0 justify-center gap-2 overflow-x-auto">
              {post.images.map((item, index) => (
                <button
                  aria-label={`Show image ${index + 1}`}
                  className={`h-16 w-16 shrink-0 overflow-hidden rounded-lg border-2 bg-white transition focus:outline-none focus:ring-4 focus:ring-cyan-100 ${
                    selectedImage === index
                      ? 'border-cyan-500'
                      : 'border-transparent opacity-65 hover:opacity-100'
                  }`}
                  key={`${item.url}-${item.position}`}
                  onClick={() => setSelectedImage(index)}
                  type="button"
                >
                  <img alt="" className="h-full w-full object-cover" src={item.url} />
                </button>
              ))}
            </div>
          ) : null}
        </section>

        <section className="min-h-0 overflow-y-auto border-l border-slate-200 bg-white p-5 sm:p-7">
          <div className="flex items-center gap-3">
            {post.authorAvatarUrl ? (
              <img
                alt=""
                className="h-11 w-11 rounded-full object-cover"
                src={post.authorAvatarUrl}
              />
            ) : (
              <span className="grid h-11 w-11 place-items-center rounded-full bg-cyan-50 text-cyan-700">
                <UserRound className="h-5 w-5" aria-hidden="true" />
              </span>
            )}
            <div className="min-w-0">
              <p className="truncate font-extrabold text-cyanZone-ink">
                {post.authorName}
              </p>
              <p className="text-xs font-semibold text-slate-400">
                Published {formatDate(post.publishedAt ?? post.createdAt)}
              </p>
            </div>
          </div>

          <div className="mt-6 flex flex-wrap items-start justify-between gap-3">
            <h3 className="min-w-0 flex-1 text-xl font-black leading-7 text-cyanZone-ink">
              {post.title}
            </h3>
            <StatusBadge status={post.moderationStatus} />
          </div>
          <p className="mt-4 whitespace-pre-wrap text-sm leading-6 text-slate-600">
            {post.content}
          </p>
          {post.tags.length ? (
            <div className="mt-5 flex flex-wrap gap-2">
              {post.tags.map((tag) => (
                <span
                  className="rounded-full border border-cyan-100 bg-cyan-50 px-3 py-1 text-xs font-bold text-cyan-700"
                  key={tag}
                >
                  {tag}
                </span>
              ))}
            </div>
          ) : null}

          <div className="my-7 border-t border-slate-200" />
          <h3 className="text-base font-black text-cyanZone-ink">
            Comments ({post.commentCount})
          </h3>
          {post.comments.length ? (
            <div className="mt-4 space-y-5">
              {post.comments.map((comment) => (
                <Comment key={comment.id} comment={comment} />
              ))}
            </div>
          ) : (
            <p className="mt-4 rounded-lg bg-slate-50 px-4 py-5 text-sm text-slate-500">
              No comments on this post yet.
            </p>
          )}
        </section>
      </div>
    </FullScreenDialog>
  );
}

function Comment({
  comment,
  nested = false,
}: {
  comment: AdminCommentView;
  nested?: boolean;
}) {
  return (
    <article className={nested ? 'ml-8 mt-4 border-l-2 border-cyan-100 pl-4' : ''}>
      <div className="flex items-start gap-3">
        {comment.authorAvatarUrl ? (
          <img
            alt=""
            className="h-9 w-9 shrink-0 rounded-full object-cover"
            src={comment.authorAvatarUrl}
          />
        ) : (
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-slate-100 text-slate-500">
            <UserRound className="h-4 w-4" aria-hidden="true" />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-sm font-extrabold text-cyanZone-ink">
              {comment.authorName}
            </span>
            {comment.isCreator ? (
              <span className="rounded-full bg-blue-50 px-2 py-0.5 text-[0.65rem] font-black uppercase tracking-wide text-blue-600">
                Creator
              </span>
            ) : null}
            <span className="text-xs text-slate-400">
              {formatDate(comment.createdAt)}
            </span>
          </div>
          <p className="mt-1 whitespace-pre-wrap text-sm leading-6 text-slate-600">
            {comment.content}
          </p>
          <span className="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-slate-400">
            <Heart className="h-3.5 w-3.5" aria-hidden="true" />
            {comment.likeCount}
          </span>
        </div>
      </div>
      {comment.replies.map((reply) => (
        <Comment comment={reply} key={reply.id} nested />
      ))}
    </article>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}
