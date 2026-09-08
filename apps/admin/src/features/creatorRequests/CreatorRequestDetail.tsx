import {
  BadgeCheck,
  CalendarDays,
  Mail,
  MessageSquareQuote,
  UserRound,
} from 'lucide-react';

import { StatusBadge } from '../../components/casework/StatusBadge';
import type { CreatorRequestDetailView } from '../../types/admin';
import { RecentPostsCarousel } from '../users/RecentPostsCarousel';

export function CreatorRequestDetail({
  request,
  onOpenPost,
}: {
  request: CreatorRequestDetailView;
  onOpenPost: (postId: string) => void;
}) {
  return (
    <div className="p-5 lg:p-6">
      <div className="flex flex-wrap items-start gap-5">
        {request.avatarUrl ? (
          <img
            alt=""
            className="h-24 w-24 rounded-full object-cover ring-4 ring-cyan-50"
            src={request.avatarUrl}
          />
        ) : (
          <span className="grid h-24 w-24 place-items-center rounded-full bg-cyan-50 text-cyan-700 ring-4 ring-cyan-50">
            <UserRound className="h-9 w-9" aria-hidden="true" />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-2xl font-black">{request.userName}</h2>
            <StatusBadge status={request.status} />
          </div>
          <div className="mt-2 flex flex-wrap gap-x-5 gap-y-2 text-sm text-slate-500">
            <span className="inline-flex items-center gap-1.5">
              <Mail className="h-4 w-4" aria-hidden="true" />
              {request.userEmail}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CalendarDays className="h-4 w-4" aria-hidden="true" />
              Member since {formatDate(request.memberSince)}
            </span>
          </div>
          <p className="mt-4 max-w-3xl text-sm leading-6 text-slate-600">
            {request.bio || 'No profile biography provided.'}
          </p>
        </div>
      </div>

      <dl className="mt-6 grid divide-y divide-slate-200 border-y border-slate-200 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
        <Fact
          icon={BadgeCheck}
          label="Account standing"
          value={request.accountStatus === 'active' ? 'Good standing' : request.accountStatus}
        />
        <Fact label="Requested on" value={formatDateTime(request.createdAt)} />
        <Fact
          label="Creator status"
          value={request.isContentCreator ? 'Already assigned' : 'Not assigned'}
        />
      </dl>

      <section className="mt-6 rounded-xl border border-amber-200 bg-amber-50/70 p-4">
        <div className="flex items-center gap-2 text-sm font-black text-amber-900">
          <MessageSquareQuote className="h-4 w-4" aria-hidden="true" />
          Requester statement
        </div>
        <p className="mt-2 text-sm leading-6 text-amber-950/80">
          {request.reason || 'No application statement was provided.'}
        </p>
      </section>

      <section className="mt-6">
        <h3 className="text-sm font-black uppercase tracking-wide text-slate-500">
          Recent published content
        </h3>
        {request.recentPosts.length === 0 ? (
          <p className="mt-3 rounded-lg bg-slate-50 px-4 py-5 text-sm text-slate-500">
            No recent published posts.
          </p>
        ) : (
          <div className="mt-3">
            <RecentPostsCarousel
              onOpenPost={onOpenPost}
              posts={request.recentPosts}
            />
          </div>
        )}
      </section>

      {request.status !== 'pending' ? (
        <section className="mt-6 rounded-xl border border-slate-200 bg-slate-50 p-4">
          <h3 className="text-sm font-black">Recorded decision</h3>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            {request.adminNote || 'No administrator note was recorded.'}
          </p>
          <p className="mt-2 text-xs text-slate-500">
            {request.reviewedBy ?? 'Administrator'}
            {request.reviewedAt
              ? ` · ${formatDateTime(request.reviewedAt)}`
              : ''}
          </p>
        </section>
      ) : null}
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

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('en-MY', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
