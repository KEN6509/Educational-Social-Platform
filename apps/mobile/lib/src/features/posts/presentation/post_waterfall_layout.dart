import 'package:flutter/material.dart';

import '../data/aspect_ratio_cache.dart';
import '../data/feed_post.dart';
import 'post_card_ratio_preloader.dart';

class WaterfallColumns {
  const WaterfallColumns({
    required this.left,
    required this.right,
  });

  final List<FeedPost> left;
  final List<FeedPost> right;
}

WaterfallColumns buildWaterfallColumns(
  List<FeedPost> posts, {
  required double cardWidth,
  required double spacing,
  double Function(FeedPost post)? ratioForPost,
}) {
  final left = <FeedPost>[];
  final right = <FeedPost>[];
  var leftHeight = 0.0;
  var rightHeight = 0.0;

  for (final post in posts) {
    final estimatedHeight = estimatePostCardHeight(
      post,
      cardWidth: cardWidth,
      ratioForPost: ratioForPost,
    );
    if (leftHeight <= rightHeight) {
      left.add(post);
      leftHeight += estimatedHeight + spacing;
    } else {
      right.add(post);
      rightHeight += estimatedHeight + spacing;
    }
  }

  return WaterfallColumns(left: left, right: right);
}

class SliverPostWaterfallGrid extends StatelessWidget {
  const SliverPostWaterfallGrid({
    required this.posts,
    required this.cardBuilder,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 24),
    this.spacing = 12,
    super.key,
  });

  final List<FeedPost> posts;
  final Widget Function(BuildContext context, FeedPost post) cardBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(
        child: PostWaterfallGrid(
          posts: posts,
          cardBuilder: cardBuilder,
          spacing: spacing,
        ),
      ),
    );
  }
}

class PostWaterfallGrid extends StatelessWidget {
  const PostWaterfallGrid({
    required this.posts,
    required this.cardBuilder,
    this.spacing = 12,
    super.key,
  });

  final List<FeedPost> posts;
  final Widget Function(BuildContext context, FeedPost post) cardBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        final columns = buildWaterfallColumns(
          posts,
          cardWidth: cardWidth,
          spacing: spacing,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cardWidth,
              child: _PostWaterfallColumn(
                posts: columns.left,
                spacing: spacing,
                cardBuilder: cardBuilder,
              ),
            ),
            SizedBox(width: spacing),
            SizedBox(
              width: cardWidth,
              child: _PostWaterfallColumn(
                posts: columns.right,
                spacing: spacing,
                cardBuilder: cardBuilder,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PostWaterfallColumn extends StatelessWidget {
  const _PostWaterfallColumn({
    required this.posts,
    required this.spacing,
    required this.cardBuilder,
  });

  final List<FeedPost> posts;
  final double spacing;
  final Widget Function(BuildContext context, FeedPost post) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < posts.length; index++) ...[
          cardBuilder(context, posts[index]),
          if (index != posts.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

double estimatePostCardHeight(
  FeedPost post, {
  required double cardWidth,
  double Function(FeedPost post)? ratioForPost,
}) {
  if (post.isTextOnly) {
    return estimateTextOnlyPostSurfaceHeight(post.content, cardWidth) + 92;
  }
  final ratio = ratioForPost?.call(post) ?? _cachedRatioForPost(post);
  final imageHeight = cardWidth / ratio;
  const titleAndMetaHeight = 76.0;
  return imageHeight + titleAndMetaHeight;
}

double _cachedRatioForPost(FeedPost post) {
  final url = post.imageUrls.firstOrNull;
  if (url == null) return PostCardRatioPreloader.square;
  return AspectRatioCache.get(url) ?? PostCardRatioPreloader.square;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
