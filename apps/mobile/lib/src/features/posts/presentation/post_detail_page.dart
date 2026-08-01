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
import '../data/aspect_ratio_cache.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_avatar_cache.dart';
import '../../profile/presentation/profile_page.dart';
import 'comment_date_formatter.dart';
import 'create_post_page.dart';
import 'comment_reply_visibility.dart';
import 'post_feedback_snackbar.dart';
import 'report_post_page.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    required this.post,
    this.heroTag,
    this.initialAuthorAvatarBytes,
    this.initialCommentId,
    super.key,
  });

  final FeedPost post;
  final String? heroTag;
  final Uint8List? initialAuthorAvatarBytes;
  final String? initialCommentId;

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
              final repo = PostsRepository(Supabase.instance.client);
              await repo.createComment(
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
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Comment posted!'),
                  ),
                );
                await _refreshPostState(updateCommentCount: false);
                await _fetchComments();
              }
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

class _CommentsLoadError extends StatelessWidget {
  const _CommentsLoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 34,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              friendlyErrorTitle(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4490AD),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDetailNetworkImage extends StatefulWidget {
  const _PostDetailNetworkImage({
    required this.url,
    required this.allowCache,
  });

  final String url;
  final bool allowCache;

  @override
  State<_PostDetailNetworkImage> createState() =>
      _PostDetailNetworkImageState();
}

class _PostDetailNetworkImageState extends State<_PostDetailNetworkImage> {
  late Future<File?> _imageFuture;
  File? _displayedFile;

  @override
  void initState() {
    super.initState();
    _displayedFile = PostImageDiskCache.peek(widget.url);
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant _PostDetailNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.allowCache != widget.allowCache) {
      _displayedFile = null;
      _displayedFile = PostImageDiskCache.peek(widget.url);
      _imageFuture = _loadImage();
    }
  }

  Future<File?> _loadImage() async {
    if (!widget.allowCache) return null;
    final requestedUrl = widget.url;
    final file = await PostImageDiskCache.cachedFile(requestedUrl) ??
        await PostImageDiskCache.cacheUrl(requestedUrl);
    if (mounted &&
        file != null &&
        widget.allowCache &&
        widget.url == requestedUrl) {
      setState(() => _displayedFile = file);
    }
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowCache) {
      return _networkImage();
    }

    final displayedFile = _displayedFile;
    if (displayedFile != null) {
      return Image.file(displayedFile, fit: BoxFit.contain);
    }

    return FutureBuilder<File?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(file, fit: BoxFit.contain);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _networkImage();
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 34, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              const Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _networkImage() {
    return Image.network(
      widget.url,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}

class _PostDetailImagePreviewPage extends StatefulWidget {
  const _PostDetailImagePreviewPage({
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTags,
    required this.onClosing,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final List<String> heroTags;
  final ValueChanged<int> onClosing;

  @override
  State<_PostDetailImagePreviewPage> createState() =>
      _PostDetailImagePreviewPageState();
}

class _PostDetailImagePreviewPageState
    extends State<_PostDetailImagePreviewPage> {
  late final PageController _controller;
  late int _index;
  bool _isDownloading = false;
  bool _isClosing = false;
  bool _isCurrentImageZoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePreview();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(child: _buildSingleImagePager()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _PostDetailPreviewHeader(
                title: '${_index + 1}/$total',
                isDownloading: _isDownloading,
                onBack: _closePreview,
                onDownload: _downloadCurrentImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleImagePager() {
    return PageView.builder(
      controller: _controller,
      physics: _isCurrentImageZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: widget.imageUrls.length,
      onPageChanged: (value) {
        setState(() {
          _index = value;
          _isCurrentImageZoomed = false;
        });
      },
      itemBuilder: (context, index) {
        final image = _PostDetailZoomablePreviewImage(
          imageUrl: widget.imageUrls[index],
          onTap: _closePreview,
          onZoomChanged: index == _index
              ? (isZoomed) {
                  if (mounted && _isCurrentImageZoomed != isZoomed) {
                    setState(() => _isCurrentImageZoomed = isZoomed);
                  }
                }
              : null,
          onZoomOut: _closePreview,
        );
        if (index == _index) {
          return Hero(tag: widget.heroTags[index], child: image);
        }
        return image;
      },
    );
  }

  Future<void> _closePreview() async {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    widget.onClosing(_index);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(_index);
  }

  void _showPhotoCouldNotLoad() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo could not load')),
    );
  }

  Future<void> _downloadCurrentImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final client = HttpClient();
    try {
      final url = widget.imageUrls[_index];
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo access is required to download images'),
          ),
        );
        return;
      }

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showPhotoCouldNotLoad();
        return;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      await PhotoManager.editor.saveImage(
        bytes,
        filename: _downloadFilenameFor(url),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo downloaded')),
      );
    } catch (_) {
      _showPhotoCouldNotLoad();
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _downloadFilenameFor(String url) {
    final uri = Uri.tryParse(url);
    final pathName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'post-photo.jpg';
    final cleanName = pathName.split('?').first.trim();
    if (cleanName.isEmpty) return 'post-photo.jpg';
    if (cleanName.contains('.')) return cleanName;
    return '$cleanName.jpg';
  }
}

class _PostDetailZoomablePreviewImage extends StatefulWidget {
  const _PostDetailZoomablePreviewImage({
    required this.imageUrl,
    required this.onTap,
    required this.onZoomOut,
    this.onZoomChanged,
  });

  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onZoomOut;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_PostDetailZoomablePreviewImage> createState() =>
      _PostDetailZoomablePreviewImageState();
}

class _PostDetailZoomablePreviewImageState
    extends State<_PostDetailZoomablePreviewImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _settleController;
  Animation<Matrix4>? _settleAnimation;
  Offset? _lastFocalPoint;
  bool _canPanImage = false;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final animation = _settleAnimation;
        if (animation != null) {
          _transformationController.value = animation.value;
        }
      });
  }

  @override
  void dispose() {
    _settleController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.85,
        maxScale: 4.8,
        boundaryMargin: const EdgeInsets.all(160),
        panEnabled: _canPanImage,
        onInteractionUpdate: (details) {
          _lastFocalPoint = details.focalPoint;
          final scale = _transformationController.value.getMaxScaleOnAxis();
          final canPanImage = scale > 1.01;
          if (_canPanImage != canPanImage) {
            setState(() => _canPanImage = scale > 1.01);
          }
          widget.onZoomChanged?.call(scale > 1.01);
        },
        onInteractionEnd: (_) {
          final scale = _transformationController.value.getMaxScaleOnAxis();
          if (scale < 0.97) {
            widget.onZoomOut();
          } else if (scale > 4) {
            _settleToScale(4);
          } else {
            widget.onZoomChanged?.call(scale > 1.01);
          }
        },
        child: Center(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              return const _PostDetailImageLoadError(compact: true);
            },
          ),
        ),
      ),
    );
  }

  void _settleToScale(double scale) {
    final focalPoint = _lastFocalPoint ??
        Offset(
          MediaQuery.sizeOf(context).width / 2,
          MediaQuery.sizeOf(context).height / 2,
        );
    _settleAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: _matrixWithPreservedViewportPoint(scale, focalPoint),
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController.forward(from: 0);
  }

  Matrix4 _matrixWithPreservedViewportPoint(
    double targetScale,
    Offset viewportPoint,
  ) {
    final current = _transformationController.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale <= 0) return _matrixForScale(targetScale, viewportPoint);
    final ratio = targetScale / currentScale;
    final currentTranslation = current.getTranslation();
    final targetTranslation = Offset(
      viewportPoint.dx - ratio * (viewportPoint.dx - currentTranslation.x),
      viewportPoint.dy - ratio * (viewportPoint.dy - currentTranslation.y),
    );
    return Matrix4.diagonal3Values(targetScale, targetScale, 1)
      ..setTranslationRaw(targetTranslation.dx, targetTranslation.dy, 0);
  }

  Matrix4 _matrixForScale(double scale, Offset focalPoint) {
    return Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
  }
}

class _PostDetailPreviewHeader extends StatelessWidget {
  const _PostDetailPreviewHeader({
    required this.title,
    required this.isDownloading,
    required this.onBack,
    required this.onDownload,
  });

  final String title;
  final bool isDownloading;
  final VoidCallback onBack;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xB3000000),
            Color(0x66000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _PostDetailPreviewHeaderButton(
                tooltip: 'Back',
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: onBack,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
              _PostDetailPreviewHeaderButton(
                tooltip: 'Download',
                icon: Icons.download_rounded,
                isLoading: isDownloading,
                onPressed: onDownload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostDetailPreviewHeaderButton extends StatelessWidget {
  const _PostDetailPreviewHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(
              icon,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 10),
              ],
            ),
    );
  }
}

class _PostDetailImageLoadError extends StatelessWidget {
  const _PostDetailImageLoadError({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: compact ? 220 : double.infinity,
        child: Text(
          'Photo could not load',
          textAlign: TextAlign.center,
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF475569),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _CommentInputModal extends StatelessWidget {
  const _CommentInputModal({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.replyToName,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final String? replyToName;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyToName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $replyToName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onCancelReply,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Say something...',
                        hintStyle:
                            TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        counterText: "",
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onSend,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4490AD),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.post,
    required this.onToggleDislike,
    required this.onShare,
    required this.onReport,
    this.showOwnerActions = false,
    this.onEdit,
    this.onDelete,
  });

  final FeedPost post;
  final VoidCallback onToggleDislike;
  final Future<void> Function() onShare;
  final VoidCallback onReport;
  final bool showOwnerActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  static List<ChatConversation> _recentShareContactsCache =
      const <ChatConversation>[];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final ChatRepository _chatRepository;
  List<ChatConversation> _allContacts = [];
  List<ChatConversation> _selectedContacts = [];
  final Set<String> _tickedConversationIds = {};
  List<ChatConversation> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingContacts = true;
  bool _isSending = false;
  bool _isSheetExpanded = false;
  double? _sheetDragHeight;
  late final ScrollController _scrollController;
  final ScrollController _searchScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository(Supabase.instance.client);
    _scrollController = ScrollController();
    _searchFocusNode.addListener(_onSearchFocusChange);
    if (_recentShareContactsCache.isNotEmpty) {
      _allContacts = List<ChatConversation>.from(_recentShareContactsCache);
      _selectedContacts = _allContacts.take(9).toList();
      _searchResults = List.from(_allContacts);
      _isLoadingContacts = false;
    }
    _loadRecentContacts();
  }

  Future<void> _loadRecentContacts() async {
    try {
      final conversations = await _chatRepository.fetchConversations();
      if (!mounted) return;
      setState(() {
        _allContacts = conversations
            .where((conversation) => !conversation.isRequest)
            .toList();
        _recentShareContactsCache = List<ChatConversation>.from(_allContacts);
        _selectedContacts = _allContacts.take(9).toList();
        _searchResults = List.from(_allContacts);
        _isLoadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (_recentShareContactsCache.isNotEmpty) {
        setState(() => _isLoadingContacts = false);
        return;
      }
      setState(() {
        _allContacts = const [];
        _selectedContacts = const [];
        _searchResults = const [];
        _isLoadingContacts = false;
      });
    }
  }

  void _onSearchFocusChange() {
    // Triggers height change when search bar is focused
    if (mounted) {
      setState(() {
        // When focusing, we are "searching" even if query is empty
        if (_searchFocusNode.hasFocus) {
          _isSearching = _searchController.text.isNotEmpty;
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchScrollController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = List.from(_allContacts);
      });
      return;
    }

    final normalized = query.toLowerCase().trim();
    setState(() {
      _isSearching = true;
      _searchResults = _allContacts
          .where(
            (conversation) =>
                conversation.displayTitle.toLowerCase().contains(normalized),
          )
          .toList();
    });
  }

  void _addContact(ChatConversation contact) {
    setState(() {
      if (!_selectedContacts.any((c) => c.id == contact.id)) {
        _selectedContacts.add(contact);
      }
      _tickedConversationIds.add(contact.id);
      _isSearching = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
    });
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_tickedConversationIds.contains(conversationId)) {
        _tickedConversationIds.remove(conversationId);
      } else {
        _tickedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _sendSharedPost() async {
    if (_tickedConversationIds.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final body = ChatMessage.sharedPostBody(
      postId: widget.post.id,
      authorName: widget.post.authorName,
      authorAvatarUrl: widget.post.authorAvatarUrl,
      title: widget.post.title,
      content: widget.post.content,
      imageUrl: widget.post.imageUrls.firstOrNull,
    );

    try {
      for (final conversationId in _tickedConversationIds) {
        await _chatRepository.sendMessage(
          conversationId: conversationId,
          body: body,
        );
      }
      try {
        await widget.onShare();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context);
      _showShareSnackBar('Post sent.', success: true);
    } catch (_) {
      if (!mounted) return;
      _showShareSnackBar('No internet connection');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showShareSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
              color:
                  success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double statusBarHeight = view.padding.top / view.devicePixelRatio;
    final double defaultHeight = _defaultSheetHeight(context);
    final double expandedHeight = screenHeight - statusBarHeight - 8;
    final bool isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final bool isInputMode =
        _searchFocusNode.hasFocus || _isSearching || isKeyboardOpen;
    final double currentHeight = _sheetDragHeight ??
        (isInputMode || _isSheetExpanded ? expandedHeight : defaultHeight);

    return PopScope(
      canPop: !isInputMode && !_isSheetExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isInputMode) {
          setState(() {
            _searchFocusNode.unfocus();
            _isSearching = false;
            _searchController.clear();
          });
        } else if (!didPop && _isSheetExpanded) {
          setState(() => _isSheetExpanded = false);
        }
      },
      child: GestureDetector(
        onVerticalDragStart: (_) => _startSheetDrag(currentHeight),
        onVerticalDragUpdate: (details) => _updateSheetDrag(
          details,
          minHeight: defaultHeight,
          maxHeight: expandedHeight,
        ),
        onVerticalDragEnd: _handleSheetDragEnd,
        behavior: HitTestBehavior.translucent,
        child: AnimatedContainer(
          duration: _sheetDragHeight == null
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          height: currentHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Redesigned Search Bar (matching main_shell.dart style)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearch,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFF1E293B)),
                        decoration: appSearchInputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Color(0xFF94A3B8)),
                          suffixIcon: _isSearching
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                    _onSearch('');
                                  },
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Content
                  Expanded(
                    child: Stack(
                      children: [
                        // Friends Grid (Hidden when in input mode)
                        if (!isInputMode)
                          Scrollbar(
                            controller: _scrollController,
                            thickness: 4,
                            radius: const Radius.circular(2),
                            child: ListView(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                if (_isLoadingContacts)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 30),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF4490AD),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_selectedContacts.isEmpty)
                                  _buildEmptyState()
                                else
                                  _buildContactGrid(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        // Search Results Overlay
                        if (isInputMode)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white,
                              child: Scrollbar(
                                controller: _searchScrollController,
                                child: ListView.builder(
                                  controller: _searchScrollController,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final contact = _searchResults[index];
                                    return ListTile(
                                      leading: _ShareContactAvatar(
                                        conversation: contact,
                                        radius: 22,
                                      ),
                                      title: Text(
                                        contact.displayTitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      trailing: _tickedConversationIds
                                              .contains(contact.id)
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF4490AD))
                                          : null,
                                      onTap: () => _addContact(contact),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Fixed Quick Actions Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                        0, 12, 0, 24), // Added bottom padding
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: _buildActionRow(),
                  ),
                ],
              ),
              // Send Button Overlay with Background
              if (_tickedConversationIds.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                        16, 12, 16, 32), // Increased bottom padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4490AD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSending ? null : _sendSharedPost,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _tickedConversationIds.length == 1
                                        ? 'Send'
                                        : 'Send separately',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSheetDrag(double currentHeight) {
    setState(() => _sheetDragHeight = currentHeight);
  }

  void _updateSheetDrag(
    DragUpdateDetails details, {
    required double minHeight,
    required double maxHeight,
  }) {
    final currentHeight = _sheetDragHeight ?? minHeight;
    final nextHeight = (currentHeight - details.delta.dy).clamp(
      minHeight,
      maxHeight,
    );
    setState(() => _sheetDragHeight = nextHeight.toDouble());
  }

  void _handleSheetDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final statusBarHeight = view.padding.top / view.devicePixelRatio;
    final minHeight = _defaultSheetHeight(context);
    final maxHeight = mediaQuery.size.height - statusBarHeight - 8;
    final currentHeight =
        _sheetDragHeight ?? (_isSheetExpanded ? maxHeight : minHeight);
    final midpoint = minHeight + ((maxHeight - minHeight) * 0.5);
    final shouldExpand =
        velocity < -180 || (velocity.abs() <= 180 && currentHeight > midpoint);

    setState(() {
      _sheetDragHeight = null;
      _isSheetExpanded = shouldExpand;
      if (!shouldExpand) {
        _searchFocusNode.unfocus();
        _isSearching = false;
        _searchController.clear();
      }
    });
  }

  double _defaultSheetHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const handleHeight = 24.0;
    const searchHeight = 56.0;
    const actionBarHeight = 127.0;
    final contentHeight = _recentContactsContentHeight;
    final targetHeight =
        handleHeight + searchHeight + contentHeight + actionBarHeight;
    return targetHeight.clamp(screenHeight * 0.34, screenHeight * 0.5);
  }

  double get _recentContactsContentHeight {
    if (_isLoadingContacts || _selectedContacts.isEmpty) {
      return 124;
    }
    return _recentContactRows * 108.0 + 12;
  }

  int get _recentContactRows {
    if (_selectedContacts.isEmpty) return 1;
    return ((_selectedContacts.length + 2) ~/ 3).clamp(1, 3);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 40, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          const Text(
            'No recent chats',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Open Messages'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactGrid() {
    final gridHeight = _recentContactRows * 108.0;
    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedContacts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
          childAspectRatio: 1.12,
        ),
        itemBuilder: (context, index) {
          final contact = _selectedContacts[index];
          final isSelected = _tickedConversationIds.contains(contact.id);
          return GestureDetector(
            onTap: () => _toggleSelection(contact.id),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Stack(
                  children: [
                    _ShareContactAvatar(
                      conversation: contact,
                      radius: 38,
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 24,
                            color: Color(0xFF4490AD),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    contact.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: widget.showOwnerActions
              ? [
                  _ActionGridItem(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEdit?.call();
                    },
                  ),
                  const SizedBox(width: 20),
                  _ActionGridItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: const Color(0xFFDC2626),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete?.call();
                    },
                  ),
                ]
              : [
                  _ActionGridItem(
                    icon: Icons.sentiment_dissatisfied_rounded,
                    label: 'Dislike',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onToggleDislike();
                    },
                  ),
                  const SizedBox(width: 20),
                  _ActionGridItem(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onReport();
                    },
                  ),
                ],
        ),
      ),
    );
  }
}

class _ShareContactAvatar extends StatelessWidget {
  const _ShareContactAvatar({
    required this.conversation,
    required this.radius,
  });

  final ChatConversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroup) {
      return GroupAvatar(
        seed: conversation.id,
        size: radius * 2,
      );
    }

    return ChatAvatar(
      name: conversation.displayTitle,
      avatarUrl: conversation.otherUserAvatarUrl,
      size: radius * 2,
    );
  }
}

class _ActionGridItem extends StatelessWidget {
  const _ActionGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF475569),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72, // Reduced to 72px as requested
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _ViewRepliesButton extends StatelessWidget {
  const _ViewRepliesButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 0, bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 1,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 8),
            Text(
              formatHiddenRepliesLabel(count),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends StatefulWidget {
  const _CommentItem({
    required this.authorId,
    required this.commentId,
    required this.name,
    required this.content,
    required this.time,
    required this.onLongPress,
    required this.onAuthorTap,
    required this.onReply,
    required this.onTaggedUserTap,
    required this.ensureOnline,
    this.avatarUrl,
    this.taggedUserName,
    this.taggedUserId,
    this.isContentCreator = false,
    this.likeCount = 0,
    this.initialIsLiked = false,
    this.isPostAuthor = false,
    this.isLikedByPostAuthor = false,
    this.isPinned = false,
    this.isReply = false,
    super.key,
  });

  final String authorId;
  final String commentId;
  final String name;
  final String content;
  final String time;
  final String? avatarUrl;
  final String? taggedUserName;
  final String? taggedUserId;
  final bool isContentCreator;
  final int likeCount;
  final bool initialIsLiked;
  final bool isPostAuthor;
  final bool isLikedByPostAuthor;
  final bool isPinned;
  final bool isReply;
  final VoidCallback onLongPress;
  final VoidCallback onAuthorTap;
  final VoidCallback onReply;
  final ValueChanged<String> onTaggedUserTap;
  final Future<bool> Function() ensureOnline;

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  late bool _isLiked;
  late int _likeCount;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likeCount = widget.likeCount;
  }

  Future<void> _toggleLike() async {
    if (_isProcessing) return;
    if (!await widget.ensureOnline()) return;

    setState(() {
      _isProcessing = true;
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.toggleCommentLike(widget.commentId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = widget.initialIsLiked;
          _likeCount = widget.likeCount;
        });
        if (friendlyErrorTitle(e) == 'No internet connection') {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('No internet connection'),
              ),
            );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: widget.isReply ? 34 : 0,
        bottom: widget.isReply ? 9 : 10,
      ),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.translucent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onAuthorTap,
              behavior: HitTestBehavior.opaque,
              child: CircleAvatar(
                radius: widget.isReply ? 11 : 16,
                backgroundColor: const Color(0xFFE7F8F5),
                backgroundImage: widget.avatarUrl != null
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null
                    ? Text(
                        widget.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF2C7189),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: widget.isReply ? 6 : 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: widget.onAuthorTap,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      _CommentMetaBadge(
                        isAuthorComment: widget.isPostAuthor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _CommentContentText(
                    content: widget.content,
                    taggedUserName: widget.taggedUserName,
                    taggedUserId: widget.taggedUserId,
                    onTaggedUserTap: widget.onTaggedUserTap,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onReply,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          height: 17,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _CommentSecondaryMeta(
                        isLikedByAuthor:
                            !widget.isPostAuthor && widget.isLikedByPostAuthor,
                        isPinned: widget.isPinned,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(top: 17),
              child: _CommentLikeButton(
                isLiked: _isLiked,
                likeCount: _likeCount,
                onTap: _toggleLike,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentMetaBadge extends StatelessWidget {
  const _CommentMetaBadge({required this.isAuthorComment});

  final bool isAuthorComment;

  @override
  Widget build(BuildContext context) {
    if (!isAuthorComment) return const SizedBox.shrink();

    return const Flexible(
      child: Text(
        ' \u00B7 Author',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CommentSecondaryMeta extends StatelessWidget {
  const _CommentSecondaryMeta({
    required this.isLikedByAuthor,
    required this.isPinned,
  });

  final bool isLikedByAuthor;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    if (!isLikedByAuthor && !isPinned) return const SizedBox.shrink();

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLikedByAuthor) ...[
              const Text(
                ' \u00B7 ',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.favorite_rounded,
                size: 12,
                color: Color(0xFFE11D48),
              ),
              const Flexible(
                child: Text(
                  ' by Author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (isPinned)
              const Flexible(
                child: Text(
                  ' \u00B7 Pinned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4490AD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentContentText extends StatelessWidget {
  const _CommentContentText({
    required this.content,
    required this.onTaggedUserTap,
    this.taggedUserName,
    this.taggedUserId,
  });

  final String content;
  final String? taggedUserName;
  final String? taggedUserId;
  final ValueChanged<String> onTaggedUserTap;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      color: Color(0xFF475569),
      height: 1.32,
    );
    final name = taggedUserName;
    final id = taggedUserId;
    final mention = name == null ? null : '@$name';
    if (mention == null || id == null || !content.startsWith(mention)) {
      return Text(content, style: baseStyle);
    }

    final rest = content.substring(mention.length);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: mention,
            style: baseStyle.copyWith(
              color: const Color(0xFF2C7189),
              fontWeight: FontWeight.w700,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => onTaggedUserTap(id),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
  }
}

class _CommentActionTile extends StatelessWidget {
  const _CommentActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? const Color(0xFFE11D48) : const Color(0xFF334155);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  });

  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isLiked ? const Color(0xFFE11D48) : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 36,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: color,
            ),
            if (likeCount > 0)
              Positioned(
                top: 22,
                child: Text(
                  likeCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
