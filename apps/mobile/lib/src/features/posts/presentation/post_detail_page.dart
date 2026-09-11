import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_widgets.dart' show ChatAvatar, GroupAvatar;
import '../data/feed_post.dart';
import '../data/post_comment.dart';
import '../data/post_image_disk_cache.dart';
import '../data/posts_repository.dart';
import '../domain/content_moderation.dart';
import '../domain/post_submission_repository.dart';
import '../data/aspect_ratio_cache.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_avatar_cache.dart';
import '../../profile/presentation/profile_page.dart';
import 'comment_date_formatter.dart';
import 'create_post_page.dart';
import 'comment_reply_visibility.dart';
import 'post_feedback_snackbar.dart';
import 'report_post_page.dart';
import 'content_moderation_scope.dart';

part 'post_detail_media.dart';
part 'post_share_sheet.dart';
part 'post_detail_comments.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    required this.post,
    this.heroTag,
    this.initialAuthorAvatarBytes,
    this.initialCommentId,
    this.repository,
    super.key,
  });

  final FeedPost post;
  final String? heroTag;
  final Uint8List? initialAuthorAvatarBytes;
  final String? initialCommentId;
  final PostSubmissionRepository? repository;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late FeedPost _post;
  late bool _isLiked;
  late int _likeCount;
  late bool _isDisliked;
  late int _dislikeCount;
  late bool _isSaved;
  late int _saveCount;
  late int _shareCount;
  late int _commentCount;
  bool _isFollowing = false;
  bool _isProcessingLike = false;
  bool _isProcessingDislike = false;
  bool _isProcessingSave = false;
  bool _isProcessingFollow = false;
  List<PostComment>? _comments;
  Object? _commentsError;
  bool _isLoadingComments = true;
  late PageController _pageController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final FocusNode _postTextSelectionFocusNode = FocusNode();
  final GlobalKey _commentsKey = GlobalKey();
  final Map<String, GlobalKey> _commentKeys = <String, GlobalKey>{};
  final Set<String> _expandedCommentIds = {};
  Uint8List? _cachedAuthorAvatarBytes;
  bool _isOfflineMode = true;
  bool _handledInitialComment = false;
  bool _isOpeningImagePreview = false;
  bool _hasPostTextSelection = false;
  final Set<int> _activeImagePointers = <int>{};
  int _currentPage = 0;
  double _aspectRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(keepPage: false);
    _post = widget.post;
    _isLiked = _post.isLiked;
    _likeCount = _post.likeCount;
    _isDisliked = _post.isDisliked;
    _dislikeCount = _post.dislikeCount;
    _isSaved = _post.isSaved;
    _saveCount = _post.saveCount;
    _shareCount = _post.shareCount;
    _commentCount = _post.commentCount;
    _cachedAuthorAvatarBytes = widget.initialAuthorAvatarBytes ??
        ProfileAvatarCache.peek(_post.authorId);
    _detectOfflineMode();
    _restoreCachedAuthorAvatar();
    _resolveFirstImageAspectRatio();
    if (_post.imageUrls.isNotEmpty) {
      unawaited(PostImageDiskCache.cacheUrls(_post.imageUrls));
    }
    _fetchComments();
    _loadFollowState();
    _refreshPostState(updateCommentCount: false);
  }

  bool get _isOwner {
    return _post.isOwnedBy(Supabase.instance.client.auth.currentUser?.id);
  }

  Future<void> _detectOfflineMode() async {
    final isOnline = await _hasInternetConnection();
    if (!mounted) return;
    setState(() {
      _isOfflineMode = !isOnline;
      if (_isOfflineMode) {
        _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    });
  }

  Future<void> _restoreCachedAuthorAvatar() async {
    final bytes = await ProfileAvatarCache.restoreOrFetch(
      userId: _post.authorId,
      url: _post.authorAvatarUrl,
    );
    if (!mounted || bytes == null) return;
    setState(() => _cachedAuthorAvatarBytes = bytes);
  }

  Future<void> _fetchComments() async {
    if (mounted) {
      setState(() {
        _isLoadingComments = true;
        _commentsError = null;
      });
    }
    try {
      final repo = PostsRepository(Supabase.instance.client);
      final comments = await repo.fetchComments(_post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsError = null;
          _commentCount = comments.length;
          _isLoadingComments = false;
        });
        _focusInitialComment(comments);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commentsError = e;
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _loadFollowState() async {
    if (_isOwner) return;
    try {
      final repository = ProfileRepository(Supabase.instance.client);
      final isFollowing = await repository.isFollowing(_post.authorId);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Keep cached post details visible while offline.
    }
  }

  Future<void> _refreshPostState({bool updateCommentCount = false}) async {
    try {
      final repo = PostsRepository(Supabase.instance.client);
      final freshPost = await repo.fetchPostById(_post.id);
      if (!mounted) return;
      _applyPostState(freshPost, updateCommentCount: updateCommentCount);
    } catch (_) {
      // Keep cached post details visible while offline.
    }
  }

  void _applyPostState(FeedPost post, {bool updateCommentCount = true}) {
    setState(() {
      _isLiked = post.isLiked;
      _post = post;
      _likeCount = post.likeCount;
      _isDisliked = post.isDisliked;
      _dislikeCount = post.dislikeCount;
      _isSaved = post.isSaved;
      _saveCount = post.saveCount;
      _shareCount = post.shareCount;
      if (updateCommentCount) {
        _commentCount = post.commentCount;
      }
    });
  }

  void _scrollToComments() {
    final context = _commentsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  GlobalKey _commentKey(String commentId) {
    return _commentKeys.putIfAbsent(commentId, GlobalKey.new);
  }

  void _focusInitialComment(List<PostComment> comments) {
    final commentId = widget.initialCommentId;
    if (_handledInitialComment || commentId == null || commentId.isEmpty) {
      return;
    }
    _handledInitialComment = true;

    final target =
        comments.where((comment) => comment.id == commentId).firstOrNull;
    if (target == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('This comment was deleted or is no longer available.'),
          ),
        );
      });
      return;
    }

    if (target.parentCommentId != null) {
      setState(() => _expandedCommentIds.add(target.parentCommentId!));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _commentKey(commentId).currentContext;
      if (context == null) {
        _scrollToComments();
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
  }

  void _resolveFirstImageAspectRatio() {
    if (_post.imageUrls.isEmpty) return;

    final url = _post.imageUrls.first;

    // Check cache first
    final cached = AspectRatioCache.get(url);
    if (cached != null) {
      setState(() {
        _aspectRatio = cached;
      });
      return;
    }

    // Resolve manually
    final cachedFile = PostImageDiskCache.peek(url);
    final image =
        cachedFile == null ? Image.network(url) : Image.file(cachedFile);
    image.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((info, _) {
            if (mounted) {
              final w = info.image.width.toDouble();
              final h = info.image.height.toDouble();
              final rawRatio = w / h;

              // Snap to 3:4, 1:1, or 4:3
              double finalRatio;
              if (rawRatio < 0.85) {
                finalRatio = 0.75; // 3:4
              } else if (rawRatio > 1.15) {
                finalRatio = 1.33; // 4:3
              } else {
                finalRatio = 1.0; // 1:1
              }

              AspectRatioCache.set(url, finalRatio);
              setState(() {
                _aspectRatio = finalRatio;
              });
            }
          }, onError: (_, __) {}),
        );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _postTextSelectionFocusNode.dispose();
    super.dispose();
  }

  void _clearPostTextSelection() {
    if (!_hasPostTextSelection) return;
    setState(() => _hasPostTextSelection = false);
    _postTextSelectionFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _toggleLike() async {
    if (_isProcessingLike) return;
    if (!await _ensureInteractionAllowed()) return;

    setState(() {
      _isProcessingLike = true;
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
        // If it was disliked, undislike it
        if (_isDisliked) {
          _isDisliked = false;
          _dislikeCount--;
        }
      }
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleLike(_post.id);
      await _refreshPostState();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = _post.isLiked;
          _likeCount = _post.likeCount;
          _isDisliked = _post.isDisliked;
          _dislikeCount = _post.dislikeCount;
        });
        _showActionError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingLike = false);
      }
    }
  }

  Future<void> _toggleDislike() async {
    if (_isProcessingDislike) return;
    if (!await _ensureInteractionAllowed()) return;
    final wasDisliked = _isDisliked;

    setState(() {
      _isProcessingDislike = true;
      if (_isDisliked) {
        _isDisliked = false;
        _dislikeCount--;
      } else {
        _isDisliked = true;
        _dislikeCount++;
        // If it was liked, unlike it
        if (_isLiked) {
          _isLiked = false;
          _likeCount--;
        }
      }
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleDislike(_post.id);
      await _refreshPostState();
      if (mounted && !wasDisliked && _isDisliked) {
        _showDislikeFeedback();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDisliked = _post.isDisliked;
          _dislikeCount = _post.dislikeCount;
          _isLiked = _post.isLiked;
          _likeCount = _post.likeCount;
        });
        _showActionError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingDislike = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isProcessingFollow) return;
    if (_isOwner) return;
    if (!await _ensureInteractionAllowed()) return;

    final oldIsFollowing = _isFollowing;
    setState(() {
      _isProcessingFollow = true;
      _isFollowing = !_isFollowing;
    });
    try {
      final repository = ProfileRepository(Supabase.instance.client);
      final isFollowing = await repository.toggleFollow(_post.authorId);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFollowing = oldIsFollowing);
      _showActionError(e);
    } finally {
      if (mounted) {
        setState(() => _isProcessingFollow = false);
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_isProcessingSave) return;
    if (!await _ensureInteractionAllowed()) return;

    setState(() {
      _isProcessingSave = true;
      if (_isSaved) {
        _isSaved = false;
        _saveCount--;
      } else {
        _isSaved = true;
        _saveCount++;
      }
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleSave(_post.id);
      await _refreshPostState();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = _post.isSaved;
        });
        _showActionError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingSave = false);
      }
    }
  }

  Future<bool> _ensureOnline() async {
    if (await _hasInternetConnection()) return true;
    if (!mounted) return false;
    _showNoInternetMessage();
    return false;
  }

  Future<bool> _ensureInteractionAllowed() async {
    if (!_post.allowsInteractions) {
      if (mounted) {
        final message = _post.isRejected
            ? 'This post was rejected. Actions are unavailable.'
            : 'This post is still under review. Actions are unavailable.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(message),
            ),
          );
      }
      return false;
    }
    return _ensureOnline();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showNoInternetMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No internet connection'),
        ),
      );
  }

  void _showActionError(Object error) {
    if (friendlyErrorTitle(error) == 'No internet connection') {
      _showNoInternetMessage();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = _post;
    final visibleImageUrls = _isOfflineMode && post.imageUrls.isNotEmpty
        ? post.imageUrls.take(1).toList()
        : post.imageUrls;
    final ImageProvider<Object>? authorAvatarImage =
        _cachedAuthorAvatarBytes != null
            ? MemoryImage(_cachedAuthorAvatarBytes!)
            : post.authorAvatarUrl != null
                ? NetworkImage(post.authorAvatarUrl!)
                : null;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_getUpdateResult()),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openAuthorProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE7F8F5),
                backgroundImage: authorAvatarImage,
                onBackgroundImageError:
                    authorAvatarImage == null ? null : (_, __) {},
                child: authorAvatarImage == null
                    ? Text(
                        post.authorName.characters.first.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF2C7189),
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: _isOwner
            ? [
                IconButton(
                  onPressed: () => _showOwnerActionsSheet(context),
                  icon: const Icon(Icons.more_horiz_rounded, size: 26),
                ),
                const SizedBox(width: 4),
              ]
            : [
                _FollowButton(
                  isFollowing: _isFollowing,
                  onTap: _toggleFollow,
                ),
                IconButton(
                  onPressed: () => _showShareSheet(context),
                  icon: const Icon(Icons.share_outlined, size: 22),
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: GestureDetector(
        onTap: _clearPostTextSelection,
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Carousel
              if (visibleImageUrls.isNotEmpty)
                AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _isOfflineMode
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: visibleImageUrls.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final heroTag = _postImageHeroTag(index);
                      return Listener(
                        onPointerDown: (event) => _handleImagePointerDown(
                          event,
                          visibleImageUrls,
                          index,
                          previewEnabled: !_isOfflineMode,
                        ),
                        onPointerUp: _handleImagePointerEnd,
                        onPointerCancel: _handleImagePointerEnd,
                        child: GestureDetector(
                          onTap: _isOfflineMode
                              ? null
                              : () => _openImagePreview(
                                    visibleImageUrls,
                                    initialIndex: index,
                                  ),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            color: Colors.white,
                            child: Hero(
                              tag: heroTag,
                              child: _PostDetailNetworkImage(
                                url: visibleImageUrls[index],
                                allowCache: true,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (visibleImageUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      visibleImageUrls.length,
                      (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? const Color(0xFF4490AD)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionArea(
                      focusNode: _postTextSelectionFocusNode,
                      onSelectionChanged: (content) {
                        final hasSelection =
                            content != null && content.plainText.isNotEmpty;
                        if (_hasPostTextSelection != hasSelection) {
                          setState(() => _hasPostTextSelection = hasSelection);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1F3E),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.content,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (post.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: post.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Color(0xFF4490AD),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        // Row(
                        //   children: [
                        //     const Icon(Icons.share_rounded,
                        //         size: 14, color: Color(0xFF94A3B8)),
                        //     const SizedBox(width: 4),
                        //     Text(
                        //       '$_shareCount shares',
                        //       style: theme.textTheme.bodySmall?.copyWith(
                        //         color: const Color(0xFF94A3B8),
                        //         fontSize: 12,
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 24),
                    _buildCommentsSection(theme, key: _commentsKey),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showCommentModal(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded,
                          size: 20, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text(
                        'Say something...',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _ActionButton(
              icon: _isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color:
                  _isLiked ? const Color(0xFFE11D48) : const Color(0xFF475569),
              label: _likeCount.toString(),
              onTap: _toggleLike,
            ),
            _ActionButton(
              icon: _isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color:
                  _isSaved ? const Color(0xFFEAB308) : const Color(0xFF475569),
              label: _saveCount.toString(),
              onTap: _toggleSave,
            ),
            _ActionButton(
              icon: Icons.share_outlined,
              color: const Color(0xFF475569),
              label: _shareCount.toString(),
              onTap: () => _showShareSheet(context),
            ),
            _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF475569),
              label: _commentCount.toString(),
              onTap: _scrollToComments,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommentModal({
    PostComment? replyTo,
    String? parentCommentId,
  }) async {
    if (!await _ensureInteractionAllowed()) return;
    if (!mounted) return;
    if (replyTo != null) {
      _commentController.text = '@${replyTo.authorName} ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentInputModal(
        controller: _commentController,
        focusNode: _commentFocusNode,
        replyToName: replyTo?.authorName,
        onCancelReply: replyTo == null
            ? null
            : () {
                _commentController.clear();
                Navigator.pop(context);
              },
        onSend: () async {
          final content = _commentController.text.trim();
          if (content.isNotEmpty) {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            if (!await _ensureInteractionAllowed()) return;
            _commentController.clear();
            navigator.pop();

            try {
              final repo = widget.repository ??
                  PostsRepository(Supabase.instance.client);
              final commentId = await repo.createComment(
                _post.id,
                content,
                parentCommentId: parentCommentId ?? replyTo?.id,
                taggedUserId: _shouldKeepReplyMention(content, replyTo)
                    ? replyTo!.authorId
                    : null,
                taggedUserName: _shouldKeepReplyMention(content, replyTo)
                    ? replyTo!.authorName
                    : null,
              );
              await _moderateComment(commentId, messenger);
            } catch (e) {
              if (mounted) {
                if (friendlyErrorTitle(e) == 'No internet connection') {
                  _showNoInternetMessage();
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text(friendlyErrorMessage(e))),
                  );
                }
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _moderateComment(
    String commentId,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final result =
          await ContentModerationScope.of(context).moderateComment(commentId);
      if (!mounted) return;
      switch (result.state) {
        case ContentModerationState.approved:
          messenger
              .showSnackBar(const SnackBar(content: Text('Comment posted!')));
          await _refreshPostState(updateCommentCount: false);
          await _fetchComments();
        case ContentModerationState.adminReview:
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Comment sent for administrator review.')),
          );
        case ContentModerationState.processing:
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Comment moderation is still processing.')),
          );
        case ContentModerationState.rejected:
          messenger.showSnackBar(
            SnackBar(content: Text(result.reason ?? 'Comment was not posted.')),
          );
        case ContentModerationState.superseded:
          messenger.showSnackBar(
            const SnackBar(
                content: Text('This comment changed. Please submit it again.')),
          );
        case ContentModerationState.failed:
          _showCommentModerationRetry(commentId, messenger);
      }
    } on ContentModerationFailure catch (error) {
      if (!mounted) return;
      if (error.retryAllowed) {
        _showCommentModerationRetry(commentId, messenger);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _showCommentModerationRetry(
    String commentId,
    ScaffoldMessengerState messenger,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Comment moderation could not complete.'),
          action: SnackBarAction(
            label: 'Retry moderation',
            onPressed: () => _moderateComment(commentId, messenger),
          ),
        ),
      );
  }

  Map<String, dynamic> _getUpdateResult() {
    return _post
        .copyWith(
          isLiked: _isLiked,
          likeCount: _likeCount,
          isDisliked: _isDisliked,
          dislikeCount: _dislikeCount,
          isSaved: _isSaved,
          saveCount: _saveCount,
          shareCount: _shareCount,
          commentCount: _commentCount,
        )
        .toCardUpdateResult();
  }

  String _formatDate(DateTime date) {
    return formatPostDate(date, DateTime.now());
  }

  String _postImageHeroTag(int index) {
    if (index == 0) {
      return widget.heroTag ?? 'post_image_${_post.id}';
    }
    return 'post_image_${_post.id}_$index';
  }

  Future<void> _openImagePreview(
    List<String> imageUrls, {
    required int initialIndex,
  }) async {
    if (imageUrls.isEmpty || _isOpeningImagePreview) return;
    setState(() => _isOpeningImagePreview = true);
    try {
      final returnedIndex = await Navigator.of(context).push<int>(
        PageRouteBuilder<int>(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: _PostDetailImagePreviewPage(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
              heroTags: List.generate(
                imageUrls.length,
                (index) => _postImageHeroTag(index),
              ),
              onClosing: _alignImagePreviewPage,
            ),
          ),
        ),
      );
      if (returnedIndex != null) {
        _alignImagePreviewPage(returnedIndex);
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningImagePreview = false);
      }
    }
  }

  void _handleImagePointerDown(
    PointerDownEvent event,
    List<String> imageUrls,
    int index, {
    required bool previewEnabled,
  }) {
    if (!previewEnabled) return;
    _activeImagePointers.add(event.pointer);
    if (_activeImagePointers.length >= 2) {
      _activeImagePointers.clear();
      _openImagePreview(
        imageUrls,
        initialIndex: index,
      );
    }
  }

  void _handleImagePointerEnd(PointerEvent event) {
    _activeImagePointers.remove(event.pointer);
  }

  void _alignImagePreviewPage(int index) {
    if (!mounted || _post.imageUrls.isEmpty) return;
    final safeIndex = index.clamp(0, _post.imageUrls.length - 1);
    if (_currentPage != safeIndex) {
      setState(() => _currentPage = safeIndex);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(safeIndex);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(safeIndex);
      }
    });
  }

  Future<void> _showShareSheet(BuildContext context) async {
    if (!await _ensureInteractionAllowed()) return;
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // User cannot drag manually
      isDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _ShareSheet(
        post: _post,
        onToggleDislike: _toggleDislike,
        onShare: _recordShare,
        onReport: () async {
          final navigator = Navigator.of(context);
          if (!await _ensureInteractionAllowed()) return;
          if (!context.mounted) return;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ReportPostPage(postId: _post.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showOwnerActionsSheet(BuildContext context) async {
    if (!await _ensureOnline()) return;
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _ShareSheet(
        post: _post,
        onToggleDislike: _toggleDislike,
        onShare: _recordShare,
        onReport: () {},
        showOwnerActions: true,
        onEdit: _openEditPost,
        onDelete: _deletePost,
      ),
    );
  }

  Future<void> _openEditPost() async {
    final navigator = Navigator.of(context);
    if (!await _ensureOnline()) return;
    await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          editPost: _post,
          onPostCreated: () {
            _refreshPostState();
          },
        ),
      ),
    );
    if (!mounted) return;
    await _refreshPostState();
  }

  Future<void> _openAuthorProfile() async {
    final navigator = Navigator.of(context);
    if (!await _ensureOnline()) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: _post.authorId,
          initialName: _post.authorName,
          initialAvatarUrl: _post.authorAvatarUrl,
          initialAvatarBytes: _cachedAuthorAvatarBytes,
          initialIsContentCreator: _post.authorIsContentCreator,
        ),
      ),
    );
  }

  Future<void> _deletePost() async {
    final navigator = Navigator.of(context);
    if (!await _ensureOnline()) return;
    final confirmed = await _showPostDecisionDialog(
      icon: Icons.delete_outline_rounded,
      iconColor: const Color(0xFFDC2626),
      iconBackgroundColor: const Color(0xFFFEE2E2),
      title: 'Delete this post?',
      message:
          'This post will be removed from CyanZone. You cannot undo this action.',
      primaryLabel: 'Delete post',
      primaryColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.removePost(_post.id);
      if (!mounted) return;
      navigator.pop({'deleted': true});
    } catch (e) {
      if (!mounted) return;
      _showActionError(e);
    }
  }

  Future<bool?> _showPostDecisionDialog({
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    required String message,
    required String primaryLabel,
    required Color primaryColor,
  }) {
    return showAppConfirmationDialog(
      context: context,
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: primaryColor,
    );
  }

  Future<void> _recordShare() async {
    if (!await _ensureInteractionAllowed()) return;
    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.recordShare(_post.id);
      await _refreshPostState();
    } catch (e) {
      // Silent error for shares
    }
  }

  void _showDislikeFeedback() {
    showDislikeFeedbackSnackBar(
      context,
      onCancel: () async {
        try {
          await _toggleDislike();
        } catch (e) {
          if (!mounted) return;
          _showActionError(e);
        }
      },
      onReport: () async {
        if (!await _ensureInteractionAllowed()) return;
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportPostPage(postId: _post.id),
          ),
        );
      },
    );
  }

  Widget _buildCommentsSection(ThemeData theme, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B1F3E),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _commentCount.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4490AD),
              ),
            ),
          )
        else if (_commentsError != null)
          _CommentsLoadError(
            error: _commentsError,
            onRetry: _fetchComments,
          )
        else if (_comments == null || _comments!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No comments yet. Be the first to say something!',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ..._buildCommentThreadItems(),
      ],
    );
  }

  List<Widget> _buildCommentThreadItems() {
    final comments = _comments ?? <PostComment>[];
    final topLevel = comments.where((comment) => !comment.isReply).toList();
    topLevel.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    final repliesByParent = <String, List<PostComment>>{};

    for (final reply in comments.where((comment) => comment.isReply)) {
      repliesByParent.putIfAbsent(reply.parentCommentId!, () => []).add(reply);
    }

    return [
      for (final comment in topLevel) ...[
        _CommentItem(
          key: _commentKey(comment.id),
          commentId: comment.id,
          authorId: comment.authorId,
          name: comment.authorName,
          content: comment.content,
          time: _formatCommentDate(comment.createdAt),
          avatarUrl: comment.authorAvatarUrl,
          isContentCreator: comment.authorIsContentCreator,
          likeCount: comment.likeCount,
          initialIsLiked: comment.isLiked,
          isPostAuthor: comment.authorId == _post.authorId,
          isLikedByPostAuthor: comment.isLikedByPostAuthor,
          isPinned: comment.isPinned,
          taggedUserName: _taggedUserNameForContent(comment.content, comment),
          taggedUserId: _taggedUserIdForContent(comment, comments),
          onReply: () => _showCommentModal(replyTo: comment),
          onAuthorTap: () => _openProfile(comment.authorId),
          onTaggedUserTap: _openProfile,
          onLongPress: () => _showCommentActions(comment),
          ensureOnline: _ensureInteractionAllowed,
        ),
        if (repliesByParent[comment.id] case final replies?)
          if (_expandedCommentIds.contains(comment.id))
            for (final reply in replies)
              _CommentItem(
                key: _commentKey(reply.id),
                commentId: reply.id,
                authorId: reply.authorId,
                name: reply.authorName,
                content: reply.content,
                time: _formatCommentDate(reply.createdAt),
                avatarUrl: reply.authorAvatarUrl,
                isContentCreator: reply.authorIsContentCreator,
                likeCount: reply.likeCount,
                initialIsLiked: reply.isLiked,
                isPostAuthor: reply.authorId == _post.authorId,
                isLikedByPostAuthor: reply.isLikedByPostAuthor,
                taggedUserName: _taggedUserNameForContent(reply.content, reply),
                taggedUserId: _taggedUserIdForContent(reply, comments),
                isReply: true,
                onReply: () => _showCommentModal(
                  replyTo: reply,
                  parentCommentId: comment.id,
                ),
                onAuthorTap: () => _openProfile(reply.authorId),
                onTaggedUserTap: _openProfile,
                onLongPress: () => _showCommentActions(reply),
                ensureOnline: _ensureInteractionAllowed,
              )
          else
            _ViewRepliesButton(
              count: replies.length,
              onTap: () {
                setState(() {
                  _expandedCommentIds.add(comment.id);
                });
              },
            ),
      ],
    ];
  }

  String _formatCommentDate(DateTime dateTime) {
    return formatCommentDate(dateTime, DateTime.now());
  }

  bool _shouldKeepReplyMention(String content, PostComment? replyTo) {
    if (replyTo == null) return false;
    final mention = '@${replyTo.authorName}';
    return content == mention || content.startsWith('$mention ');
  }

  String? _taggedUserNameForContent(String content, PostComment comment) {
    final storedName = comment.taggedUserName;
    if (storedName != null &&
        (content == '@$storedName' || content.startsWith('@$storedName '))) {
      return storedName;
    }
    if (comment.taggedUserId != null && content.startsWith('@')) {
      final firstToken = content.split(RegExp(r'\s+')).first;
      return firstToken.length <= 1 ? null : firstToken.substring(1);
    }
    if (!content.startsWith('@')) return null;
    final names = (_comments ?? <PostComment>[])
        .map((comment) => comment.authorName)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      if (content == '@$name' || content.startsWith('@$name ')) {
        return name;
      }
    }
    final firstToken = content.split(' ').first;
    return firstToken.length <= 1 ? null : firstToken.substring(1);
  }

  String? _taggedUserIdForContent(
    PostComment comment,
    List<PostComment> comments,
  ) {
    if (comment.taggedUserId != null) return comment.taggedUserId;
    final taggedName = _taggedUserNameForContent(comment.content, comment);
    if (taggedName == null) return null;
    for (final comment in comments) {
      if (comment.authorName == taggedName) return comment.authorId;
    }
    return null;
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
  }

  Future<void> _showCommentActions(PostComment comment) async {
    if (!await _ensureInteractionAllowed()) return;
    if (!mounted) return;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCommentPoster = currentUserId == comment.authorId;
    final isPostAuthor = currentUserId == _post.authorId;
    final canDelete = isCommentPoster || isPostAuthor;
    final canPin = isPostAuthor && !comment.isReply;
    final canReport = !isCommentPoster;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPin)
                  _CommentActionTile(
                    icon: comment.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    label: comment.isPinned ? 'Unpin comment' : 'Pin comment',
                    onTap: () {
                      Navigator.pop(context);
                      _toggleCommentPin(comment);
                    },
                  ),
                _CommentActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy comment text',
                  onTap: () {
                    Navigator.pop(context);
                    _copyCommentText(comment);
                  },
                ),
                if (canReport)
                  _CommentActionTile(
                    icon: Icons.flag_outlined,
                    label: 'Report comment',
                    isDestructive: true,
                    onTap: () async {
                      Navigator.pop(context);
                      if (!await _ensureInteractionAllowed()) return;
                      _reportComment(comment);
                    },
                  ),
                if (canDelete)
                  _CommentActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete comment',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteComment(comment);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteComment(PostComment comment) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureInteractionAllowed()) return;
    try {
      await PostsRepository(Supabase.instance.client).deleteComment(comment.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Comment deleted.')),
      );
      await _fetchComments();
      await _refreshPostState(updateCommentCount: false);
    } catch (e) {
      if (!mounted) return;
      _showActionError(e);
    }
  }

  Future<void> _toggleCommentPin(PostComment comment) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureInteractionAllowed()) return;
    try {
      await PostsRepository(Supabase.instance.client).toggleCommentPin(
        comment.id,
        pin: !comment.isPinned,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                comment.isPinned ? 'Comment unpinned.' : 'Comment pinned.')),
      );
      _fetchComments();
    } catch (e) {
      if (!mounted) return;
      _showActionError(e);
    }
  }

  Future<void> _reportComment(PostComment comment) async {
    final navigator = Navigator.of(context);
    if (!await _ensureInteractionAllowed()) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReportPostPage.comment(commentId: comment.id),
      ),
    );
  }

  Future<void> _copyCommentText(PostComment comment) async {
    await Clipboard.setData(ClipboardData(text: comment.content));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isFollowing
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFF4490AD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                color: isFollowing ? const Color(0xFF64748B) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
