part of 'post_detail_page.dart';

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
