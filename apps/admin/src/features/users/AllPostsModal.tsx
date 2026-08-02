import { FileText, MessageCircle } from 'lucide-react';

import { FullScreenDialog } from '../../components/casework/FullScreenDialog';
import { StatusBadge } from '../../components/casework/StatusBadge';
import { AsyncState } from '../../components/casework/AsyncState';
import type { PostSummaryView } from '../../types/admin';

type Props = {
  isOpen: boolean;
  posts: PostSummaryView[];
  onClose: () => void;
  onOpenPost: (postId: string) => void;
  loading?: boolean;
  errorMessage?: string | null;
  onRetry?: () => void;
};

export function AllPostsModal({
  isOpen,
  posts,
  onClose,
  onOpenPost,
  loading = false,
  errorMessage = null,
  onRetry,
}: Props) {
  return (
    <FullScreenDialog
      isOpen={isOpen}
      label="All published posts"
      onClose={onClose}
    >
      {loading ? <AsyncState state="loading" /> : null}
      {errorMessage ? (
        <AsyncState
          errorMessage={errorMessage}
          onRetry={onRetry}
          state="error"
        />
      ) : null}
      {!loading && !errorMessage ? (
      <div className="h-full overflow-y-auto bg-slate-50 p-5 sm:p-7">
        <div className="mb-5">
          <p className="text-sm font-bold text-slate-500">
            {posts.length} published post{posts.length === 1 ? '' : 's'}
          </p>
          <p className="mt-1 text-sm text-slate-400">
            Select any post to review its complete content and discussion.
          </p>
        </div>

        <div
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
          data-testid="all-posts-grid"
        >
          {posts.map((post) => (
            <button
              aria-label={`Open post ${post.title}`}
              className="group flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white text-left shadow-sm transition hover:-translate-y-0.5 hover:border-cyan-300 hover:shadow-lg focus:outline-none focus:ring-4 focus:ring-cyan-100"
              data-testid="all-post-card"
              key={post.id}
              onClick={() => onOpenPost(post.id)}
              type="button"
            >
              <span
                className="block aspect-[4/3] w-full shrink-0 overflow-hidden bg-slate-100"
                data-testid={`all-post-media-${post.id}`}
              >
                {post.coverImageUrl ? (
                  <img
                    alt=""
                    className="block h-full w-full object-cover"
                    data-testid={`all-post-image-${post.id}`}
                    src={post.coverImageUrl}
                  />
                ) : (
                  <span className="grid h-full w-full place-items-center text-slate-400">
                    <FileText className="h-10 w-10" aria-hidden="true" />
                  </span>
                )}
              </span>
              <span className="block p-4">
                <span className="flex items-start justify-between gap-2">
                  <span className="line-clamp-2 font-extrabold leading-5 text-cyanZone-ink">
                    {post.title}
                  </span>
                  <StatusBadge status={post.moderationStatus} />
                </span>
                <span className="mt-2 line-clamp-2 text-sm leading-5 text-slate-500">
                  {post.content}
                </span>
                <span className="mt-4 flex items-center justify-between text-xs font-semibold text-slate-400">
                  <span>{formatDate(post.publishedAt ?? post.createdAt)}</span>
                  <span className="inline-flex items-center gap-1">
                    <MessageCircle className="h-3.5 w-3.5" aria-hidden="true" />
                    {post.commentCount}
                  </span>
                </span>
              </span>
            </button>
          ))}
        </div>
      </div>
      ) : null}
    </FullScreenDialog>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}
