import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/aspect_ratio_cache.dart';
import '../data/feed_post.dart';

class PostCardRatioPreloader {
  static const portrait34 = 3 / 4;
  static const square = 1.0;
  static const landscape43 = 4 / 3;

  static double bucketAspectRatio(double rawRatio) {
    final distanceTo34 = (rawRatio - portrait34).abs();
    final distanceToSquare = (rawRatio - square).abs();
    final distanceTo43 = (rawRatio - landscape43).abs();

    if (distanceTo34 <= distanceToSquare && distanceTo34 <= distanceTo43) {
      return portrait34;
    }
    if (distanceToSquare <= distanceTo43) {
      return square;
    }
    return landscape43;
  }

  static Future<void> preload(
    List<FeedPost> posts, {
    int maxPosts = 40,
  }) async {
    await AspectRatioCache.init();

    final urls = <String>{};
    for (final post in posts) {
      final url = post.imageUrls.firstOrNull;
      if (url == null || AspectRatioCache.get(url) != null) continue;
      urls.add(url);
      if (urls.length >= maxPosts) break;
    }

    await Future.wait(urls.map(_resolveAndCache));
  }

  static Future<void> _resolveAndCache(String url) async {
    final cached = AspectRatioCache.get(url);
    if (cached != null) return;

    final completer = Completer<void>();
    final stream = Image.network(url).image.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final rawRatio = info.image.width / info.image.height;
        AspectRatioCache.set(url, bucketAspectRatio(rawRatio));
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_, __) {
        AspectRatioCache.set(url, square);
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );

    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        stream.removeListener(listener);
      },
    );
  }
}

double estimateTextOnlyPostSurfaceHeight(String title, double cardWidth) {
  final trimmed = title.trim();
  final usableWidth = (cardWidth - 24).clamp(96.0, 360.0);
  final charsPerLine = (usableWidth / 8.4).floor().clamp(12, 46);
  final lineCount =
      trimmed.isEmpty ? 1 : (trimmed.length / charsPerLine).ceil();
  final comfortableLines = lineCount.clamp(1, 8);
  final height = comfortableLines * 18.0 + 4.0;
  return height.clamp(22.0, 240.0);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
