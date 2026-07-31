import {
  ChevronLeft,
  ChevronRight,
  FileText,
  MessageCircle,
} from 'lucide-react';
import { useRef, useState } from 'react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { PostSummaryView } from '../../types/admin';

type Props = {
  posts: PostSummaryView[];
  onOpenPost: (postId: string) => void;
};

const cardWidth = 280;
const cardGap = 16;

export function RecentPostsCarousel({ posts, onOpenPost }: Props) {
  const recentPosts = posts.slice(0, 5);
  const railRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState(0);

  function move(direction: -1 | 1) {
    railRef.current?.scrollBy({
      behavior: 'smooth',
      left: direction * (cardWidth + cardGap),
    });
    setPosition((current) =>
      Math.min(Math.max(current + direction, 0), recentPosts.length - 1),
    );
  }

  return (
    <div className="relative px-5 sm:px-7">
      <button
        aria-label="Previous posts"
        className="absolute left-0 top-1/2 z-10 grid h-10 w-10 -translate-y-1/2 place-items-center rounded-full border border-slate-200 bg-white text-slate-700 shadow-md transition hover:border-cyan-300 hover:text-cyan-700 disabled:cursor-not-allowed disabled:opacity-35"
        disabled={position === 0}
        onClick={() => move(-1)}
        type="button"
      >
        <ChevronLeft className="h-5 w-5" aria-hidden="true" />
      </button>

      <div
        className="flex snap-x snap-mandatory gap-4 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
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
                className="h-28 w-full object-cover"
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

      <button
        aria-label="Next posts"
        className="absolute right-0 top-1/2 z-10 grid h-10 w-10 -translate-y-1/2 place-items-center rounded-full border border-slate-200 bg-white text-slate-700 shadow-md transition hover:border-cyan-300 hover:text-cyan-700 disabled:cursor-not-allowed disabled:opacity-35"
        disabled={position >= recentPosts.length - 1}
        onClick={() => move(1)}
        type="button"
      >
        <ChevronRight className="h-5 w-5" aria-hidden="true" />
      </button>
    </div>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}
