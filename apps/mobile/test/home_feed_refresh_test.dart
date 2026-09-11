import 'dart:async';
import 'dart:math';

import 'package:cyanzone_mobile/src/features/posts/data/feed_mode.dart';
import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/home_feed_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

FeedPost _post(String id, DateTime createdAt) {
  return FeedPost(
    id: id,
    authorId: 'author',
    authorName: 'Author',
    title: id,
    content: 'Content for $id',
    tags: const [],
    moderationStatus: 'approved',
    createdAt: createdAt,
    imageUrls: const [],
    likeCount: 0,
    dislikeCount: 0,
    commentCount: 0,
    saveCount: 0,
    shareCount: 0,
    isLiked: false,
    isDisliked: false,
  );
}

void main() {
  testWidgets('mode change supersedes an in-flight refresh', (tester) async {
    final initialFeeds = Completer<List<FeedPost>>();
    final refreshingFeeds = Completer<List<FeedPost>>();
    final following = Completer<List<FeedPost>>();
    var feedCalls = 0;
    var followingCalls = 0;

    Future<List<FeedPost>> fetch(FeedMode mode) {
      if (mode == FeedMode.following) {
        followingCalls += 1;
        return following.future;
      }
      feedCalls += 1;
      return feedCalls == 1 ? initialFeeds.future : refreshingFeeds.future;
    }

    Widget page(FeedMode mode) => MaterialApp(
          home: HomeFeedPage(
            feedMode: mode,
            postsFetcher: fetch,
          ),
        );

    await tester.pumpWidget(page(FeedMode.feeds));
    initialFeeds.complete([
      _post('initial-feed', DateTime(2026, 9, 11)),
    ]);
    await tester.pumpAndSettle();

    final state = tester.state<HomeFeedPageState>(find.byType(HomeFeedPage));
    final staleRefresh = state.refresh(rearrangeFollowing: true);
    await tester.pump();
    expect(feedCalls, 2);

    await tester.pumpWidget(page(FeedMode.following));
    await tester.pump();
    expect(followingCalls, 1);

    following.complete([
      _post('following-result', DateTime(2026, 9, 12)),
    ]);
    await tester.pumpAndSettle();

    refreshingFeeds.complete([
      _post('stale-feed-result', DateTime(2026, 9, 13)),
    ]);
    await staleRefresh;
    await tester.pumpAndSettle();

    expect(find.text('following-result'), findsOneWidget);
    expect(find.text('stale-feed-result'), findsNothing);
  });

  testWidgets('automatic refresh preserves chronological Following order',
      (tester) async {
    final posts = [
      _post('newest', DateTime(2026, 9, 13)),
      _post('oldest', DateTime(2026, 9, 11)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeFeedPage(
          feedMode: FeedMode.following,
          postsFetcher: (_) async => posts,
          random: _ZeroRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<HomeFeedPageState>(find.byType(HomeFeedPage));
    final refresh = state.refresh();
    await tester.pump();
    final refreshedPosts = await tester
        .widget<FutureBuilder<List<FeedPost>>>(
          find.byType(FutureBuilder<List<FeedPost>>),
        )
        .future;
    await refresh;

    expect(
      refreshedPosts?.map((post) => post.id).toList(),
      ['newest', 'oldest'],
    );
  });
}
