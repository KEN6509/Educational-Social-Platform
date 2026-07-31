import {
  BadgeCheck,
  CalendarDays,
  Check,
  Mail,
  ShieldAlert,
  UserRound,
} from 'lucide-react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { UserDetailView } from '../../types/admin';
import { RecentPostsCarousel } from './RecentPostsCarousel';

type Props = {
  user: UserDetailView;
  onOpenPost: (postId: string) => void;
  onSeeAllPosts: () => void;
};

export function UserDetail({
  user,
  onOpenPost,
  onSeeAllPosts,
}: Props) {
  return (
    <div className="p-5 lg:p-6">
      <div className="flex flex-wrap items-start gap-4">
        {user.avatarUrl ? (
          <img
            alt=""
            className="h-20 w-20 rounded-full object-cover ring-4 ring-cyan-50"
            src={user.avatarUrl}
          />
        ) : (
          <span className="grid h-20 w-20 place-items-center rounded-full bg-cyan-50 text-cyan-700 ring-4 ring-cyan-50">
            <UserRound className="h-8 w-8" aria-hidden="true" />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <div
            className="flex flex-wrap items-center gap-2"
            data-testid="user-identity"
          >
            <span className="inline-flex items-center gap-1.5">
              <h2 className="text-2xl font-black">{user.name}</h2>
              {user.isContentCreator ? (
                <span
                  aria-label="Verified content creator"
                  className="grid h-4 w-4 shrink-0 place-items-center rounded-full bg-[#2F8FED] text-white"
                  role="img"
                >
                  <Check
                    aria-hidden="true"
                    className="h-3 w-3"
                    strokeWidth={3.5}
                  />
                </span>
              ) : null}
            </span>
            <StatusBadge status={user.accountStatus} />
          </div>
          <div className="mt-2 flex flex-wrap gap-x-5 gap-y-2 text-sm text-slate-500">
            <span className="inline-flex items-center gap-1.5">
              <Mail className="h-4 w-4" aria-hidden="true" />
              {user.email}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CalendarDays className="h-4 w-4" aria-hidden="true" />
              Member since {formatDate(user.createdAt)}
            </span>
          </div>
          <p className="mt-4 max-w-3xl text-sm leading-6 text-slate-600">
            {user.bio || 'No profile biography provided.'}
          </p>
        </div>
      </div>

      <dl className="mt-6 grid divide-y divide-slate-200 border-y border-slate-200 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
        <Fact
          icon={user.emailVerified ? BadgeCheck : ShieldAlert}
          label="Verified email"
          value={user.emailVerified ? 'Yes' : 'Not verified'}
        />
        <Fact
          label="Role"
          value={user.isContentCreator ? 'Content creator' : 'Member'}
        />
        <Fact label="Published posts" value={String(user.publishedPostCount)} />
      </dl>

      <section className="mt-6">
        <div className="flex items-center justify-between gap-4">
          <h3 className="text-sm font-black uppercase tracking-wide text-slate-500">
            Recent published content
          </h3>
          {user.publishedPostCount > 0 ? (
            <button
              className="rounded-lg px-3 py-2 text-sm font-extrabold text-cyan-700 transition hover:bg-cyan-50 focus:outline-none focus:ring-4 focus:ring-cyan-100"
              onClick={onSeeAllPosts}
              type="button"
            >
              See all posts
            </button>
          ) : null}
        </div>
        {user.recentPosts.length === 0 ? (
          <p className="mt-3 rounded-lg bg-slate-50 px-4 py-5 text-sm text-slate-500">
            No recent published posts.
          </p>
        ) : (
          <div className="mt-3">
            <RecentPostsCarousel
              onOpenPost={onOpenPost}
              posts={user.recentPosts}
            />
          </div>
        )}
      </section>
    </div>
  );
}

function Fact({
  label,
  value,
  icon: Icon,
}: {
  label: string;
  value: string;
  icon?: typeof BadgeCheck;
}) {
  return (
    <div className="px-4 py-4">
      <dt className="text-xs font-bold text-slate-400">{label}</dt>
      <dd className="mt-1 flex items-center gap-1.5 text-sm font-extrabold text-slate-700">
        {Icon ? (
          <Icon className="h-4 w-4 text-emerald-600" aria-hidden="true" />
        ) : null}
        {value}
      </dd>
    </div>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-MY', { dateStyle: 'medium' }).format(
    new Date(value),
  );
}
