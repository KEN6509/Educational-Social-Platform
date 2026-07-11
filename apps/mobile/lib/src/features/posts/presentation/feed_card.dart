import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/data/profile_avatar_cache.dart';
import '../data/feed_post.dart';
import '../data/post_image_disk_cache.dart';
import '../data/posts_repository.dart';
import '../data/aspect_ratio_cache.dart';
import '../data/post_interaction_sync.dart';
import 'post_detail_page.dart';
import 'home_feed_page.dart';
import 'post_feedback_snackbar.dart';
import 'post_card_ratio_preloader.dart';
import 'report_post_page.dart';

class FeedCard extends StatefulWidget {
  const FeedCard({
    required this.post,
    required this.showQuickActions,
    required this.onToggleQuickActions,
    this.heroTag,
    this.onResult,
    this.enableQuickActions = true,
    super.key,
  });

  final FeedPost post;
  final bool showQuickActions;
  final VoidCallback onToggleQuickActions;
  final String? heroTag;
  final ValueChanged<Map<String, dynamic>>? onResult;
  final bool enableQuickActions;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  late FeedPost _currentPost;
  Uint8List? _cachedAuthorAvatarBytes;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _cachedAuthorAvatarBytes = ProfileAvatarCache.peek(_currentPost.authorId);
    _preloadPostMedia();
    _loadAuthorAvatar();
  }

  @override
  void didUpdateWidget(FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      // Keep the current local state if we're already managing it,
      // but update if the parent provides a fresh post (e.g. from a refresh)
      _currentPost = widget.post;
      _cachedAuthorAvatarBytes = ProfileAvatarCache.peek(_currentPost.authorId);
      _preloadPostMedia();
      _loadAuthorAvatar();
    }
  }

  void _preloadPostMedia() {
    if (_currentPost.imageUrls.isEmpty) return;
    unawaited(PostImageDiskCache.cacheUrls(_currentPost.imageUrls));
  }

  Future<void> _loadAuthorAvatar() async {
    final authorId = _currentPost.authorId;
    final bytes = await ProfileAvatarCache.restoreOrFetch(
      userId: authorId,
      url: _currentPost.authorAvatarUrl,
    );
    if (!mounted || _currentPost.authorId != authorId) return;
    setState(() => _cachedAuthorAvatarBytes = bytes);
  }

  void _updatePost({
    bool? isLiked,
    int? likeCount,
    bool? isDisliked,
    int? dislikeCount,
    bool? isSaved,
    int? saveCount,
    int? commentCount,
    int? shareCount,
  }) {
    setState(() {
      _currentPost = _currentPost.copyWith(
        likeCount: likeCount,
        dislikeCount: dislikeCount,
        commentCount: commentCount,
        saveCount: saveCount,
        shareCount: shareCount,
        isLiked: isLiked,
        isDisliked: isDisliked,
        isSaved: isSaved,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    final authorAvatarImage = _authorAvatarImage();

    return Card(
      elevation: 2,
      shadowColor: const Color(0x160B1F3E),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE6F0F1)),
      ),
      child: InkWell(
        onLongPress:
            widget.enableQuickActions ? widget.onToggleQuickActions : null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          _preloadPostMedia();
          final navigator = Navigator.of(context);
          final result = await navigator.push<Map<String, dynamic>>(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  PostDetailPage(
                post: _currentPost,
                heroTag: widget.heroTag ?? 'post_image_${_currentPost.id}',
                initialAuthorAvatarBytes: _cachedAuthorAvatarBytes,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          );

          if (!mounted) return;

          Map<String, dynamic>? updateResult = result;
          if (result?['deleted'] != true) {
            try {
              final repo = PostsRepository(Supabase.instance.client);
              final freshPost = await repo.fetchPostById(_currentPost.id);
              if (!mounted) return;
              _currentPost = freshPost;
              updateResult = freshPost.toCardUpdateResult();
            } catch (_) {
              updateResult = result;
            }
          }

          if (updateResult != null) {
            PostInteractionSync.publish(
              postId: _currentPost.id,
              post: _currentPost,
              result: updateResult,
            );
            _updatePost(
              isLiked: updateResult['isLiked'],
              likeCount: updateResult['likeCount'],
              isDisliked: updateResult['isDisliked'],
              dislikeCount: updateResult['dislikeCount'],
              isSaved: updateResult['isSaved'],
              saveCount: updateResult['saveCount'],
              shareCount: updateResult['shareCount'],
              commentCount: updateResult['commentCount'],
            );

            if (widget.onResult != null) {
              widget.onResult!(updateResult);
            } else if (context.mounted) {
              // Fallback for backward compatibility
              context.findAncestorStateOfType<HomeFeedPageState>()?.refresh();
            }
          }
        },
        child: Stack(
          children: [
            Opacity(
              opacity: widget.showQuickActions ? 0.6 : 1.0,
              child: _currentPost.isTextOnly
                  ? _buildTextOnlyCard(
                      theme,
                      authorAvatarImage,
                    )
                  : _buildImageCard(
                      theme,
                      authorAvatarImage,
                    ),
            ),
            if (widget.showQuickActions)
              Positioned.fill(
                child: _QuickActionsOverlay(
                  post: _currentPost,
                  onDismiss: widget.onToggleQuickActions,
                  onReport: () {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => ReportPostPage(postId: _currentPost.id),
                      ),
                    );
                  },
                  onCancelDislike: () async {
                    final repo = PostsRepository(Supabase.instance.client);
                    await repo.toggleDislike(_currentPost.id);
                    final freshPost = await repo.fetchPostById(_currentPost.id);
                    if (mounted) {
                      _currentPost = freshPost;
                      _updatePost(
                        isLiked: freshPost.isLiked,
                        likeCount: freshPost.likeCount,
                        isDisliked: freshPost.isDisliked,
                        dislikeCount: freshPost.dislikeCount,
                      );
                    }
                    _publishPostUpdate(freshPost);
                  },
                  onUpdate: ({isLiked, likeCount, isDisliked, dislikeCount}) {
                    _updatePost(
                      isLiked: isLiked,
                      likeCount: likeCount,
                      isDisliked: isDisliked,
                      dislikeCount: dislikeCount,
                    );
                  },
                  onCompleted: (post) {
                    _publishPostUpdate(
                      post,
                      removeFromDiscovery: post.isHiddenFromDiscovery,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(
    ThemeData theme,
    ImageProvider<Object>? authorAvatarImage,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Hero(
              tag: widget.heroTag ?? 'post_image_${_currentPost.id}',
              child: _PostImage(url: _currentPost.imageUrls.first),
            ),
            if (_currentPost.isPending || _currentPost.isRejected)
              Positioned(
                top: 8,
                left: 8,
                child: _buildStatusBadge(),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentPost.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 6),
              _buildAuthorRow(theme, authorAvatarImage),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextOnlyCard(
    ThemeData theme,
    ImageProvider<Object>? authorAvatarImage,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Text(
            _currentPost.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.18,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final surfaceHeight = estimateTextOnlyPostSurfaceHeight(
                _currentPost.content, cardWidth);
            final minSurfaceHeight =
                _currentPost.isPending || _currentPost.isRejected ? 42.0 : 0.0;
            final maxSurfaceHeight = surfaceHeight < minSurfaceHeight
                ? minSurfaceHeight
                : surfaceHeight;
            return ConstrainedBox(
              key: const ValueKey('text_post_content_surface'),
              constraints: BoxConstraints(
                maxHeight: maxSurfaceHeight,
                minHeight: minSurfaceHeight,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final style = theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF536A74),
                          height: 1.42,
                        );
                        final fontSize = style?.fontSize ?? 12;
                        final lineHeight = fontSize * (style?.height ?? 1);
                        final maxLines =
                            (surfaceHeight / lineHeight).floor().clamp(
                                  1,
                                  100,
                                );
                        return Text(
                          _currentPost.content,
                          key: const ValueKey('text_post_content'),
                          maxLines: maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        );
                      },
                    ),
                  ),
                  if (_currentPost.isPending || _currentPost.isRejected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildStatusBadge(),
                    ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: _buildAuthorRow(theme, authorAvatarImage),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return _StatusBadge(
      label: _currentPost.isRejected ? 'Rejected' : 'Pending',
      icon: _currentPost.isRejected
          ? Icons.error_outline_rounded
          : Icons.hourglass_top_rounded,
      color: _currentPost.isRejected
          ? const Color(0xFFDC2626)
          : const Color(0xFF7A4A00),
      backgroundColor:
          _currentPost.isRejected ? const Color(0xFFFEE2E2) : Colors.white,
    );
  }

  Widget _buildAuthorRow(
    ThemeData theme,
    ImageProvider<Object>? authorAvatarImage,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0xFFE7F8F5),
          backgroundImage: authorAvatarImage,
          child: authorAvatarImage == null
              ? Text(
                  _currentPost.authorName.characters.first.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF2C7189),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _currentPost.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF536A74),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _LikeButton(
          postId: _currentPost.id,
          isLiked: _currentPost.isLiked,
          likeCount: _currentPost.likeCount,
          isDisliked: _currentPost.isDisliked,
          dislikeCount: _currentPost.dislikeCount,
          onToggle: ({isLiked, likeCount, isDisliked, dislikeCount}) {
            _updatePost(
              isLiked: isLiked,
              likeCount: likeCount,
              isDisliked: isDisliked,
              dislikeCount: dislikeCount,
            );
            _syncFreshPost();
          },
        ),
      ],
    );
  }

  ImageProvider<Object>? _authorAvatarImage() {
    final cachedBytes = _cachedAuthorAvatarBytes;
    if (cachedBytes != null) return MemoryImage(cachedBytes);
    final avatarUrl = _currentPost.authorAvatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    return NetworkImage(avatarUrl);
  }

  Map<String, dynamic> _resultFromPost(FeedPost post) {
    return post.toCardUpdateResult();
  }

  Future<void> _syncFreshPost() async {
    try {
      final repo = PostsRepository(Supabase.instance.client);
      final freshPost = await repo.fetchPostById(_currentPost.id);
      if (!mounted) return;
      _currentPost = freshPost;
      _publishPostUpdate(freshPost);
    } catch (_) {
      final result = _resultFromPost(_currentPost);
      PostInteractionSync.publish(
        postId: _currentPost.id,
        post: _currentPost,
        result: result,
      );
      widget.onResult?.call(result);
    }
  }

  void _publishPostUpdate(
    FeedPost post, {
    bool? removeFromDiscovery,
  }) {
    final result = {
      ..._resultFromPost(post),
      if (removeFromDiscovery != null)
        'removeFromDiscovery': removeFromDiscovery,
    };
    PostInteractionSync.publish(
      postId: post.id,
      post: post,
      result: result,
    );
    widget.onResult?.call(result);
  }
}

class _QuickActionsOverlay extends StatefulWidget {
  const _QuickActionsOverlay({
    required this.post,
    required this.onDismiss,
    required this.onUpdate,
    required this.onCompleted,
    required this.onCancelDislike,
    required this.onReport,
  });

  final FeedPost post;
  final VoidCallback onDismiss;
  final ValueChanged<FeedPost> onCompleted;
  final Future<void> Function() onCancelDislike;
  final VoidCallback onReport;
  final void Function({
    bool? isLiked,
    int? likeCount,
    bool? isDisliked,
    int? dislikeCount,
  }) onUpdate;

  @override
  State<_QuickActionsOverlay> createState() => _QuickActionsOverlayState();
}

class _QuickActionsOverlayState extends State<_QuickActionsOverlay> {
  bool _isProcessingDislike = false;

  Future<void> _handleDislike() async {
    if (_isProcessingDislike) return;

    setState(() => _isProcessingDislike = true);

    // Optimistic Update
    final wasDisliked = widget.post.isDisliked;
    final wasLiked = widget.post.isLiked;

    bool nextIsDisliked;
    int nextDislikeCount = widget.post.dislikeCount;
    bool nextIsLiked = widget.post.isLiked;
    int nextLikeCount = widget.post.likeCount;

    if (wasDisliked) {
      nextIsDisliked = false;
      nextDislikeCount--;
    } else {
      nextIsDisliked = true;
      nextDislikeCount++;
      // Mutual exclusion
      if (wasLiked) {
        nextIsLiked = false;
        nextLikeCount--;
      }
    }

    widget.onUpdate(
      isLiked: nextIsLiked,
      likeCount: nextLikeCount,
      isDisliked: nextIsDisliked,
      dislikeCount: nextDislikeCount,
    );

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleDislike(widget.post.id);
      final freshPost = await repo.fetchPostById(widget.post.id);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        widget.onUpdate(
          isLiked: freshPost.isLiked,
          likeCount: freshPost.likeCount,
          isDisliked: freshPost.isDisliked,
          dislikeCount: freshPost.dislikeCount,
        );
        widget.onCompleted(freshPost);
        showDislikeFeedbackSnackBar(
          context,
          onCancel: () async {
            try {
              await widget.onCancelDislike();
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          },
          onReport: widget.onReport,
        );
        widget.onDismiss();
      }
    } catch (e) {
      // Rollback
      widget.onUpdate(
        isLiked: wasLiked,
        likeCount: wasLiked ? widget.post.likeCount : widget.post.likeCount,
        isDisliked: wasDisliked,
        dislikeCount: widget.post.dislikeCount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingDislike = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.6),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 12,
          child: _QuickActionButton(
            icon: _isProcessingDislike
                ? Icons.hourglass_top_rounded
                : Icons.sentiment_dissatisfied_rounded,
            label: _isProcessingDislike ? 'Saving...' : 'Dislike',
            onTap: _handleDislike,
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.postId,
    required this.isLiked,
    required this.likeCount,
    required this.isDisliked,
    required this.dislikeCount,
    required this.onToggle,
  });

  final String postId;
  final bool isLiked;
  final int likeCount;
  final bool isDisliked;
  final int dislikeCount;
  final void Function({
    bool? isLiked,
    int? likeCount,
    bool? isDisliked,
    int? dislikeCount,
  }) onToggle;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isDisliked;
  late int _dislikeCount;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _isDisliked = widget.isDisliked;
    _dislikeCount = widget.dislikeCount;
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked ||
        oldWidget.likeCount != widget.likeCount ||
        oldWidget.isDisliked != widget.isDisliked ||
        oldWidget.dislikeCount != widget.dislikeCount) {
      setState(() {
        _isLiked = widget.isLiked;
        _likeCount = widget.likeCount;
        _isDisliked = widget.isDisliked;
        _dislikeCount = widget.dislikeCount;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_isProcessing) return;

    final oldIsLiked = _isLiked;
    final oldLikeCount = _likeCount;
    final oldIsDisliked = _isDisliked;
    final oldDislikeCount = _dislikeCount;

    setState(() {
      _isProcessing = true;
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
        // Mutual exclusion: if disliked, undislike
        if (_isDisliked) {
          _isDisliked = false;
          _dislikeCount--;
        }
      }
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleLike(widget.postId);
      widget.onToggle(
        isLiked: _isLiked,
        likeCount: _likeCount,
        isDisliked: _isDisliked,
        dislikeCount: _dislikeCount,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = oldIsLiked;
          _likeCount = oldLikeCount;
          _isDisliked = oldIsDisliked;
          _dislikeCount = oldDislikeCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _likeCount == 0 ? 'Like' : _likeCount.toString();

    return GestureDetector(
      onTap: _toggleLike,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 15,
              color:
                  _isLiked ? const Color(0xFFE11D48) : const Color(0xFF6E828A),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF6E828A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: const Color(0xFF334155)),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostImage extends StatefulWidget {
  const _PostImage({required this.url});

  final String? url;

  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  double? _aspectRatio;
  Future<File?>? _imageFuture;
  File? _displayedFile;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    _displayedFile = url == null ? null : PostImageDiskCache.peek(url);
    _imageFuture = _loadImage();
    _loadCachedRatio();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(_PostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final url = widget.url;
      _displayedFile = url == null ? null : PostImageDiskCache.peek(url);
      _imageFuture = _loadImage();
      _loadCachedRatio();
      _resolveAspectRatio();
    }
  }

  Future<File?> _loadImage() async {
    final url = widget.url;
    if (url == null) return null;
    final file = await PostImageDiskCache.cachedFile(url) ??
        await PostImageDiskCache.cacheUrl(url);
    if (mounted && widget.url == url && file != null) {
      setState(() => _displayedFile = file);
    }
    return file;
  }

  void _loadCachedRatio() {
    final url = widget.url;
    if (url == null) return;

    final cached = AspectRatioCache.get(url);
    if (cached != null && mounted) {
      setState(() {
        _aspectRatio = cached;
      });
    }
  }

  void _resolveAspectRatio() {
    final url = widget.url;
    if (url == null) return;

    final image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((info, _) {
            if (mounted) {
              final w = info.image.width.toDouble();
              final h = info.image.height.toDouble();
              final rawRatio = w / h;

              final finalRatio =
                  PostCardRatioPreloader.bucketAspectRatio(rawRatio);

              AspectRatioCache.set(url, finalRatio);

              setState(() {
                _aspectRatio = finalRatio;
              });
            }
          }, onError: (_, __) {}),
        );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.url;
    if (imageUrl == null) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE7FBF5), Color(0xFFDDEFF5)],
            ),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF4490AD),
            size: 38,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _aspectRatio ?? 1,
      child: _displayedFile != null
          ? Image.file(
              _displayedFile!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : FutureBuilder<File?>(
              future: _imageFuture,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) {
                  return Image.file(
                    file,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFE7F4F6)),
                  );
                }
                return const ColoredBox(
                  color: Color(0xFFE7F4F6),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF4490AD),
                  ),
                );
              },
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
