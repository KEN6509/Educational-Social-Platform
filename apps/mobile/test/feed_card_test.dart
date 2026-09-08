import 'package:cyanzone_mobile/src/features/posts/data/feed_post.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('text-only card keeps title style above flexible content surface',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final post = FeedPost(
      id: 'text-post',
      authorId: 'author',
      authorName: 'Author Name',
      title: 'A complete title that should remain visible',
      content:
          'Long content that fills the remaining card area and truncates before the author metadata row when it runs out of room.',
      tags: const [],
      moderationStatus: 'approved',
      createdAt: DateTime(2026, 6, 24),
      imageUrls: const [],
      likeCount: 4,
      dislikeCount: 0,
      commentCount: 0,
      saveCount: 0,
      shareCount: 0,
      isLiked: false,
      isDisliked: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              child: FeedCard(
                post: post,
                showQuickActions: false,
                onToggleQuickActions: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardSize = tester.getSize(find.byType(Card));
    final contentSize = tester.getSize(
      find.byKey(const ValueKey('text_post_content_surface')),
    );
    expect(cardSize.width, 180);
    expect(cardSize.height, lessThan(324));
    expect(contentSize.width, 180);
    expect(contentSize.height, lessThan(240));
    final surfaceText = tester.widget<Text>(
      find.byKey(const ValueKey('text_post_content')),
    );
    expect(surfaceText.data, post.content);
    expect(surfaceText.maxLines, greaterThan(1));
    expect(find.text(post.title), findsOneWidget);
    expect(find.textContaining('Long content'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(post.title)).dy,
      lessThan(tester.getTopLeft(find.textContaining('Long content')).dy),
    );
    final titleText = tester.widget<Text>(find.text(post.title));
    expect(titleText.maxLines, 2);
    expect(find.text('Author Name'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
  });

  testWidgets('pending text badge sits at the card top-left above the title',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final post = FeedPost(
      id: 'pending-text-post',
      authorId: 'author',
      authorName: 'Author Name',
      title: 'Pending title',
      content: 'Pending content',
      tags: const [],
      moderationStatus: 'pending',
      createdAt: DateTime(2026, 6, 24),
      imageUrls: const [],
      likeCount: 0,
      dislikeCount: 0,
      commentCount: 0,
      saveCount: 0,
      shareCount: 0,
      isLiked: false,
      isDisliked: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: FeedCard(
              post: post,
              showQuickActions: false,
              onToggleQuickActions: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardRect = tester.getRect(find.byType(Card));
    final badgeRect =
        tester.getRect(find.byKey(const ValueKey('post_status_badge')));
    final titleRect = tester.getRect(find.text('Pending title'));

    expect(badgeRect.left - cardRect.left, closeTo(8, 0.1));
    expect(badgeRect.top - cardRect.top, closeTo(8, 0.1));
    expect(titleRect.top, greaterThanOrEqualTo(badgeRect.bottom + 8));
  });

  testWidgets('short text-only card shrinks content surface near poster info',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final post = FeedPost(
      id: 'short-text-post',
      authorId: 'author',
      authorName: 'Author Name',
      title: 'Quick note',
      content: 'Oh yea',
      tags: const [],
      moderationStatus: 'approved',
      createdAt: DateTime(2026, 6, 24),
      imageUrls: const [],
      likeCount: 0,
      dislikeCount: 0,
      commentCount: 0,
      saveCount: 0,
      shareCount: 0,
      isLiked: false,
      isDisliked: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              child: FeedCard(
                post: post,
                showQuickActions: false,
                onToggleQuickActions: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final contentSurface = tester.getSize(
      find.byKey(const ValueKey('text_post_content_surface')),
    );
    expect(contentSurface.height, lessThan(30));
    final contentBottom = tester.getBottomLeft(find.text('Oh yea')).dy;
    final authorTop = tester.getTopLeft(find.text('Author Name')).dy;
    expect(authorTop - contentBottom, lessThan(12));
  });
}
