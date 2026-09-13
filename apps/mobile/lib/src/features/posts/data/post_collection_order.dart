import 'dart:math';

import 'feed_mode.dart';
import 'feed_post.dart';

/// Returns posts newest first with a stable id tie-breaker.
List<FeedPost> orderNewestPosts(Iterable<FeedPost> posts) {
  final ordered = posts.toList();
  ordered.sort((a, b) {
    final dateOrder = b.createdAt.compareTo(a.createdAt);
    return dateOrder == 0 ? b.id.compareTo(a.id) : dateOrder;
  });
  return ordered;
}

/// Returns a profile owner's posts with moderation work surfaced first.
List<FeedPost> orderProfilePosts(Iterable<FeedPost> posts) {
  final ordered = posts.toList();
  ordered.sort((a, b) {
    final statusOrder = (a.isApproved ? 1 : 0).compareTo(b.isApproved ? 1 : 0);
    if (statusOrder != 0) return statusOrder;

    final dateOrder = b.createdAt.compareTo(a.createdAt);
    return dateOrder == 0 ? b.id.compareTo(a.id) : dateOrder;
  });
  return ordered;
}

/// Keeps Following chronological on first load while allowing a manual
/// refresh to retain the existing discovery-style rearrangement.
List<FeedPost> arrangeHomePosts(
  Iterable<FeedPost> posts, {
  required FeedMode mode,
  bool rearrangeFollowing = false,
  Random? random,
}) {
  final arranged = posts.toList();
  if (mode == FeedMode.feeds ||
      (mode == FeedMode.following && rearrangeFollowing)) {
    arranged.shuffle(random);
  }
  return arranged;
}
