# Activity and New Followers Notification Redesign

Date: 2026-07-05

## Scope

This spec covers the next notification-module pass for:

- New Followers
- Activity

System Notifications are intentionally out of scope for this pass and should continue using the existing behavior unless a small shared component change requires harmless reuse.

## Goals

- Make New Followers show only useful, recent follower events.
- Make Activity feel closer to TikTok/RedNote-style social notifications instead of generic system messages.
- Give users clear visual differentiation between likes, saves, comments/replies, and mentions.
- Keep the implementation compatible with the current Supabase notification table and Flutter chat notification module.

## New Followers behavior

The New Followers page displays only `new_follower` notifications from the latest 30 days.

If the same follower follows, unfollows, and follows again within the same day, the page shows only the latest notification from that follower for that day. The dedupe key is:

- follower actor id
- local calendar date of the notification

Rows display:

- follower avatar
- follower name
- `Started following you`
- notification time
- existing Follow or Message action button

Tapping the follower row opens that follower's profile page. The Follow/Message button keeps its current direct action behavior and should not be blocked by the row tap.

## Activity behavior

The Activity page app bar title is `Activity`.

The page has a category filter styled after the image picker album dropdown:

- Activity
- Likes & Favorites
- Comments
- Mentions

Filtering maps as follows:

- Activity: all activity notification types
- Likes & Favorites: post likes and post saves/favorites
- Comments: post comments, comment replies, and comment likes
- Mentions: comment/user mentions

Rows display:

- actor avatar
- small bottom-right badge on the actor avatar
- actor name
- action text
- notification time
- right-side square preview of the related post

Badge colors:

- post like: red heart
- post save/favorite: yellow bookmark
- post comment/reply/comment like: blue comment/heart badge
- mention: green @ badge

Action text:

- `liked your post`
- `saved your post`
- `commented on your post`
- `replied to your comment`
- `liked your comment`
- `mentioned you`

The right-side preview is 1:1:

- first post image when the related post has images
- post author avatar when the related post is text-only
- neutral placeholder only if neither image nor avatar is available

Tapping an Activity row opens the related post detail when `post_id` is available. If a notification has no usable `post_id`, the row remains visually normal but does not navigate.

## Comment notification rules

The Activity notification rules follow the user-approved TikTok-like behavior without implementing "Posts you interact with" yet.

### If the current user owns the post

The post owner receives a blue-badged Activity notification for every single comment action on their post:

- original comments on the post
- replies inside any comment thread under the post

### If the current user commented on someone else's post

The comment owner receives a notification only when:

- another user directly replies to their specific comment
- another user likes their comment

The comment owner does not receive notifications for separate original comments on the same post.

### Deferred behavior

The TikTok-style "Posts you interact with" exception is not implemented in this pass. That behavior needs a separate user preference and comment-thread subscription model. It can be added later under notification settings.

## Data model changes

Extend `ChatNotification` with nullable metadata needed by the richer UI:

- `postId`
- `commentId`
- `postFirstImageUrl`
- `postAuthorAvatarUrl`

The existing actor fields remain:

- `actorId`
- `actorName`
- `actorAvatarUrl`

The repository notification select should include:

- notification ids, types, title/body, timestamps, read state
- actor profile name/avatar
- related post id/author
- related post first image ordered by image position
- post author avatar for text-only fallback

## Backend changes

Existing post like and save/favorite duplicate prevention should remain. The current trigger already prevents repeated like/save notifications for the same actor and post, which matches the anti-annoyance requirement.

Add or update notification support for:

- comment replies using `comments.parent_comment_id`
- comment likes using `comment_likes`

Notification types should be explicit enough for the client to render correct text and filters:

- `like`
- `favorite`
- `comment`
- `comment_reply`
- `comment_like`
- `mention`

The `notifications_type_check` constraint must be updated for any new notification types.

## Error and offline behavior

If loading fails due to network/offline errors, the page should show the existing no-internet state instead of misleading empty states.

Empty states should remain friendly:

- New Followers: no recent followers within 30 days
- Activity: no activity for the selected filter

## Testing

Add or update tests for:

- `ChatNotification.fromMap` parsing post/comment metadata
- New Followers 30-day filtering and same-follower same-day dedupe
- Activity filter mapping
- Activity row labels and badge differentiation
- text-only post thumbnail fallback to post author avatar
- New Followers row profile navigation
- SQL migration coverage for new notification types and comment-like trigger

Run formatting, analysis, and tests before claiming the implementation is complete.
