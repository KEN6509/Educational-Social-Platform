import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/friendly_error.dart';
import '../data/feed_mode.dart';
import '../data/feed_post.dart';
import '../data/post_interaction_sync.dart';
import '../data/post_image_disk_cache.dart';
import '../data/posts_repository.dart';
import 'feed_card.dart';
import 'feed_message.dart';
import 'post_card_ratio_preloader.dart';
import 'post_card_skeleton.dart';
import 'post_waterfall_layout.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({
    this.feedMode = FeedMode.feeds,
    this.tagFilters,
    this.onClearFilters,
    this.onCreatePost,
    super.key,
  });

  final FeedMode feedMode;
  final List<String>? tagFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onCreatePost;

  @override
  State<HomeFeedPage> createState() => HomeFeedPageState();
}

class HomeFeedPageState extends State<HomeFeedPage> {
  late PostsRepository _repository;
  Future<List<FeedPost>>? _future;
  List<FeedPost> _allPosts = [];
  bool _isRefreshing = false;
  String? _activePostId;

  @override
  void initState() {
    super.initState();
    _repository = PostsRepository(Supabase.instance.client);
    _future = _fetchPosts();
    PostInteractionSync.latest.addListener(_handlePostInteractionUpdate);
  }

  @override
  void dispose() {
    PostInteractionSync.latest.removeListener(_handlePostInteractionUpdate);
    super.dispose();
  }

  void _handlePostInteractionUpdate() {
    final update = PostInteractionSync.latest.value;
    if (!mounted || update == null) return;
    final index = _allPosts.indexWhere((post) => post.id == update.postId);
    if (index == -1) return;
    setState(() {
      _allPosts[index] = update.post;
    });
  }

  Future<List<FeedPost>> _fetchPosts() async {
    final posts = switch (widget.feedMode) {
      FeedMode.feeds => await _repository.fetchFeed(),
      FeedMode.following => await _repository.fetchFollowingPosts(),
      FeedMode.saves => await _repository.fetchSavedPosts(),
    };

    if (widget.feedMode == FeedMode.feeds) {
      posts.shuffle(Random());
    }
    unawaited(PostCardRatioPreloader.preload(posts));
    unawaited(
      PostImageDiskCache.cacheUrls(
        posts.take(12).expand((post) => post.imageUrls),
      ),
    );
    return posts;
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _future = _fetchPosts();
    });
    try {
      final posts = await _future;
      if (mounted && posts != null) {
        setState(() {
          _allPosts = posts;
        });
      }
    } catch (_) {
      // FutureBuilder renders the offline/error state for the failed fetch.
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> revealRefreshAndRefresh() async {
    if (_isRefreshing) return;
    await Future<void>.delayed(const Duration(milliseconds: 260));
    await refresh();
  }

  @override
  void didUpdateWidget(covariant HomeFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedMode != widget.feedMode) {
      refresh();
    }
  }

  List<FeedPost> _getFilteredPosts(List<FeedPost> posts) {
    final filters = widget.tagFilters;
    if (filters == null || filters.isEmpty) {
      return posts;
    }

    final hasOthers = filters.contains('others');
    final activeFilters = filters.where((t) => t != 'others').toSet();

    return posts.where((post) {
      if (post.tags.isEmpty && hasOthers) return true;
      return post.tags.any((tag) => activeFilters.contains(tag));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedPost>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _allPosts = snapshot.data ?? [];
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _allPosts.isEmpty) {
          return const _HomeFeedSkeleton();
        }

        if (snapshot.hasError) {
          return FeedMessage(
            icon: Icons.cloud_off_outlined,
            title: friendlyErrorTitle(snapshot.error),
            message: friendlyErrorMessage(snapshot.error),
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
            onAction: refresh,
            onRefresh: refresh,
          );
        }

        final posts = _getFilteredPosts(_allPosts);
        if (posts.isEmpty && _allPosts.isNotEmpty) {
          return FeedMessage(
            icon: Icons.search_off_rounded,
            title: 'No posts found for the selected topics',
            message: 'Try selecting different topics or clear filters.',
            actionLabel: 'Clear all',
            actionIcon: Icons.refresh_rounded,
            onAction: () {
              widget.onClearFilters?.call();
            },
            onRefresh: refresh,
          );
        }

        if (_allPosts.isEmpty &&
            snapshot.connectionState == ConnectionState.done) {
          String title;
          String message;
          IconData icon;
          String actionLabel = 'Refresh';
          IconData actionIcon = Icons.refresh_rounded;
          VoidCallback? onActionOverride;

          switch (widget.feedMode) {
            case FeedMode.following:
              title = 'No posts from people you follow';
              message = 'Follow some users to see their posts here.';
              icon = Icons.people_outline_rounded;
              break;
            case FeedMode.saves:
              title = 'No saved posts yet';
              message = 'Explore "Feeds" to find and save interesting content.';
              icon = Icons.bookmark_border_rounded;
              break;
            case FeedMode.feeds:
              title = 'Create your first post';
              message =
                  "Share your notes, questions, or just a happy moment today!";
              icon = Icons.auto_stories_outlined;
              actionLabel = 'Create';
              actionIcon = Icons.add_rounded;
              onActionOverride = widget.onCreatePost;
              break;
          }

          return FeedMessage(
            icon: icon,
            title: title,
            message: message,
            actionLabel: actionLabel,
            actionIcon: actionIcon,
            onAction: onActionOverride ?? refresh,
            onRefresh: refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPostWaterfallGrid(
                posts: posts,
                cardBuilder: (context, post) {
                  return FeedCard(
                    key: ValueKey('home_post_${post.id}'),
                    post: post,
                    heroTag: 'home_post_${post.id}',
                    showQuickActions: _activePostId == post.id,
                    onToggleQuickActions: () {
                      setState(() {
                        _activePostId =
                            _activePostId == post.id ? null : post.id;
                      });
                    },
                    onResult: (result) {
                      setState(() {
                        final index =
                            _allPosts.indexWhere((p) => p.id == post.id);
                        if (index != -1) {
                          if (result['deleted'] == true) {
                            _allPosts.removeAt(index);
                            return;
                          }
                          if (result['removeFromDiscovery'] == true) {
                            _allPosts.removeAt(index);
                            return;
                          }
                          final p = _allPosts[index];
                          _allPosts[index] = p.copyWith(
                            likeCount: result['likeCount'] ?? p.likeCount,
                            dislikeCount:
                                result['dislikeCount'] ?? p.dislikeCount,
                            commentCount:
                                result['commentCount'] ?? p.commentCount,
                            saveCount: result['saveCount'] ?? p.saveCount,
                            shareCount: result['shareCount'] ?? p.shareCount,
                            isLiked: result['isLiked'] ?? p.isLiked,
                            isDisliked: result['isDisliked'] ?? p.isDisliked,
                            isSaved: result['isSaved'] ?? p.isSaved,
                            dislikeHiddenUntil: result['dislikeHiddenUntil'] ??
                                p.dislikeHiddenUntil,
                          );
                        }
                      });
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFeedSkeleton extends StatelessWidget {
  const _HomeFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: PostWaterfallSkeleton(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 24),
      ),
    );
  }
}
