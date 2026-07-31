import {
  ChevronLeft,
  ChevronRight,
  FileText,
  MessageCircle,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { PostSummaryView } from '../../types/admin';

type Props = {
  posts: PostSummaryView[];
  onOpenPost: (postId: string) => void;
};

const cardWidth = 280;
const cardGap = 16;

export function RecentPostsCarousel({ posts, onOpenPost }: Props) {
  const recentPosts = useMemo(() => posts.slice(0, 5), [posts]);
  const railRef = useRef<HTMLDivElement>(null);
  const [hasOverflow, setHasOverflow] = useState(false);
  const [canScrollPrevious, setCanScrollPrevious] = useState(false);
  const [canScrollNext, setCanScrollNext] = useState(false);

  const measure = useCallback(() => {
    const rail = railRef.current;
    if (!rail) return;
    const overflow = rail.scrollWidth > rail.clientWidth + 1;
    setHasOverflow(overflow);
    setCanScrollPrevious(overflow && rail.scrollLeft > 1);
    setCanScrollNext(
      overflow &&
        rail.scrollLeft + rail.clientWidth < rail.scrollWidth - 1,
    );
  }, []);

  useEffect(() => {
    measure();
    const rail = railRef.current;
    if (!rail) return;
    if (typeof ResizeObserver !== 'undefined') {
      const observer = new ResizeObserver(measure);
      observer.observe(rail);
      return () => observer.disconnect();
    }
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [measure, recentPosts]);

  function move(direction: -1 | 1) {
    railRef.current?.scrollBy({
      behavior: 'smooth',
      left: direction * (cardWidth + cardGap),
    });
  }

  return (
    <div className="relative px-5 sm:px-7">
      {hasOverflow ? (
        <button
          aria-label="Previous posts"
          className="absolute left-0 top-1/2 z-10 grid h-10 w-10 -translate-y-1/2 place-items-center rounded-full border border-slate-200 bg-white text-slate-700 shadow-md transition hover:border-cyan-300 hover:text-cyan-700 disabled:cursor-not-allowed disabled:opacity-35"
          disabled={!canScrollPrevious}
          onClick={() => move(-1)}
          type="button"
        >
          <ChevronLeft className="h-5 w-5" aria-hidden="true" />
        </button>
      ) : null}

      <div
        className="flex snap-x snap-mandatory gap-4 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        data-testid="recent-posts-rail"
        onScroll={measure}
        ref={railRef}
      >
        {recentPosts.map((post) => (
          <button
            aria-label={`Open post ${post.title}`}
            className="group min-h-56 w-[280px] shrink-0 snap-start overflow-hidden rounded-xl border border-slate-200 bg-white text-left transition hover:-translate-y-0.5 hover:border-cyan-300 hover:shadow-lg focus:outline-none focus:ring-4 focus:ring-cyan-100"
            key={post.id}
            onClick={() => onOpenPost(post.id)}
            type="button"
          >
            {post.coverImageUrl ? (
              <img
                alt=""
                className="block h-28 w-full object-cover"
                src={post.coverImageUrl}
              />
            ) : (
              <span className="grid h-28 w-full place-items-center bg-slate-100 text-slate-400">
                <FileText className="h-8 w-8" aria-hidden="true" />
              </span>
            )}
            <span className="block p-3.5">
              <span className="flex items-start justify-between gap-2">
                <span className="line-clamp-1 font-extrabold text-cyanZone-ink">
                  {post.title}
                </span>
                <StatusBadge status={post.moderationStatus} />
              </span>
              <span className="mt-1.5 line-clamp-2 text-sm leading-5 text-slate-500">
                {post.content}
              </span>
              <span className="mt-3 flex items-center justify-between text-xs font-semibold text-slate-400">
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

      {hasOverflow ? (
        <button
          aria-label="Next posts"
          className="absolute right-0 top-1/2 z-10 grid h-10 w-10 -translate-y-1/2 place-items-center rounded-full border border-slate-200 bg-white text-slate-700 shadow-md transition hover:border-cyan-300 hover:text-cyan-700 disabled:cursor-not-allowed disabled:opacity-35"
          disabled={!canScrollNext}
          onClick={() => move(1)}
          type="button"
        >
          <ChevronRight className="h-5 w-5" aria-hidden="true" />
        </button>
      ) : null}
    </div>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}
