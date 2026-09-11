part of 'chat_widgets.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.body,
    required this.isMine,
    this.isDeleted = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.createdAt,
    this.senderName,
    this.previewSenderName,
    this.showSenderName = false,
    this.onTap,
    this.onLongPress,
    this.onSharedPostTap,
    this.mentions = const [],
    this.onMentionTap,
  });

  final String body;
  final bool isMine;
  final bool isDeleted;
  final bool isSelected;
  final bool isSelectionMode;
  final DateTime? createdAt;
  final String? senderName;
  final String? previewSenderName;
  final bool showSenderName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<ChatSharedPost>? onSharedPostTap;
  final List<ChatMention> mentions;
  final ValueChanged<String>? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final imageUrls =
        isDeleted ? const <String>[] : ChatMessage.imageUrlsFor(body);
    final imageAspectRatios =
        isDeleted ? const <double>[] : ChatMessage.imageAspectRatiosFor(body);
    final sharedPost = isDeleted ? null : ChatMessage.sharedPostFor(body);
    final hasImage = imageUrls.isNotEmpty;
    final hasRichContent = hasImage || sharedPost != null;
    final time = createdAt == null ? null : _formatBubbleTime(createdAt!);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth * 0.74;
    final timestampStyle = _bubbleTimestampStyle();
    return AnimatedContainer(
      key: isSelected ? ValueKey('chat-message-selected-row-$body') : null,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF0F766E).withValues(alpha: 0.13)
            : Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: sharedPost != null && !isSelectionMode
                ? () => onSharedPostTap?.call(sharedPost)
                : onTap,
            onLongPress: onLongPress,
            behavior: HitTestBehavior.opaque,
            child: Container(
              key: const ValueKey('chat-message-bubble'),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: EdgeInsets.symmetric(
                horizontal: hasRichContent ? 4 : 13,
                vertical: hasRichContent ? 4 : 8,
              ),
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth,
              ),
              decoration: BoxDecoration(
                color: isMine ? chatMineBubble : chatOtherBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border:
                    isMine ? null : Border.all(color: const Color(0xFFE7DED4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSenderName && !isMine && senderName != null) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        left: hasRichContent ? 9 : 0,
                        right: hasRichContent ? 9 : 0,
                        bottom: 3,
                      ),
                      child: Text(
                        senderName!,
                        style: const TextStyle(
                          color: chatMentionAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (sharedPost != null)
                    _SharedPostBubbleContent(
                      post: sharedPost,
                      time: time,
                      timeStyle: timestampStyle,
                      maxWidth: bubbleMaxWidth - 8,
                    )
                  else if (!hasImage)
                    _InlineBubbleTextWithTime(
                      body: body,
                      time: time,
                      maxWidth: bubbleMaxWidth - 26,
                      mentions: mentions,
                      onMentionTap: isSelectionMode ? null : onMentionTap,
                    )
                  else
                    _ImageBubbleContent(
                      imageUrls: imageUrls,
                      imageAspectRatios: imageAspectRatios,
                      time: time,
                      timeStyle: timestampStyle,
                      maxWidth: bubbleMaxWidth - 8,
                      senderName: previewSenderName ?? senderName ?? 'Someone',
                      sentAt: createdAt,
                      isSelectionMode: isSelectionMode,
                      onSelectionTap: onTap,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedPostBubbleContent extends StatelessWidget {
  const _SharedPostBubbleContent({
    required this.post,
    required this.time,
    required this.timeStyle,
    required this.maxWidth,
  });

  final ChatSharedPost post;
  final String? time;
  final TextStyle timeStyle;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = math.min(maxWidth, 248.0);
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Card(
            elevation: 2,
            shadowColor: const Color(0x160B1F3E),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6F0F1)),
            ),
            child: hasImage
                ? _SharedPostImageCardBody(post: post, theme: theme)
                : _SharedPostTextCardBody(post: post, theme: theme),
          ),
          if (time != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(time!, style: timeStyle),
            ),
          ],
        ],
      ),
    );
  }
}

class _SharedPostImageCardBody extends StatelessWidget {
  const _SharedPostImageCardBody({
    required this.post,
    required this.theme,
  });

  final ChatSharedPost post;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            post.imageUrl!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFE7F4F6),
              child: Icon(
                Icons.broken_image_outlined,
                color: chatCyan,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title.isEmpty ? 'Shared post' : post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: chatNavy,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 6),
              _SharedPostAuthorRow(post: post, theme: theme),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedPostTextCardBody extends StatelessWidget {
  const _SharedPostTextCardBody({
    required this.post,
    required this.theme,
  });

  final ChatSharedPost post;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Text(
            post.title.isEmpty ? 'Shared post' : post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: chatNavy,
              fontWeight: FontWeight.w600,
              height: 1.18,
            ),
          ),
        ),
        if (post.content.trim().isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 86),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Text(
              post.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF536A74),
                height: 1.42,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: _SharedPostAuthorRow(post: post, theme: theme),
        ),
      ],
    );
  }
}

class _SharedPostAuthorRow extends StatelessWidget {
  const _SharedPostAuthorRow({
    required this.post,
    required this.theme,
  });

  final ChatSharedPost post;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = post.authorAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0xFFE7F8F5),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl.trim()) : null,
          onBackgroundImageError: hasAvatar ? (_, __) {} : null,
          child: hasAvatar ? null : _SharedPostFallbackAvatar(post: post),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            post.authorName.isEmpty ? 'CyanZone' : post.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF536A74),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedPostFallbackAvatar extends StatelessWidget {
  const _SharedPostFallbackAvatar({required this.post});

  final ChatSharedPost post;

  @override
  Widget build(BuildContext context) {
    final initial = post.authorName.trim().isEmpty
        ? 'C'
        : post.authorName.trim().characters.first.toUpperCase();
    return Text(
      initial,
      style: const TextStyle(
        color: Color(0xFF2C7189),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InlineBubbleTextWithTime extends StatelessWidget {
  const _InlineBubbleTextWithTime({
    required this.body,
    required this.time,
    required this.maxWidth,
    required this.mentions,
    this.onMentionTap,
  });

  final String body;
  final String? time;
  final double maxWidth;
  final List<ChatMention> mentions;
  final ValueChanged<String>? onMentionTap;

  static const _bodyStyle = TextStyle(
    color: Color(0xFF1F2937),
    fontSize: 15,
    height: 1.28,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final mentionSpans = _mentionSpans();
    final bodySpan = TextSpan(
      text: mentionSpans == null ? body : null,
      style: _bodyStyle,
      children: mentionSpans,
    );
    if (time == null) {
      return Text.rich(bodySpan);
    }

    final timeStyle = _bubbleTimestampStyle();
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final measurementMentionSpans =
        mentionSpans == null ? null : _mentionSpans(interactive: false);
    final bodyPainter = TextPainter(
      text: TextSpan(
        text: measurementMentionSpans == null ? body : null,
        style: _bodyStyle,
        children: measurementMentionSpans,
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final timePainter = TextPainter(
      text: TextSpan(text: time, style: timeStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final lines = bodyPainter.computeLineMetrics();
    final lastLineWidth = lines.isEmpty ? 0.0 : lines.last.width;
    const timeGap = 10.0;
    final canShareLastLine = !body.endsWith('\n') &&
        lastLineWidth + timePainter.width + timeGap <= maxWidth;

    if (canShareLastLine) {
      final width = math
          .max(
            bodyPainter.width,
            lastLineWidth + timePainter.width + timeGap,
          )
          .clamp(0.0, maxWidth);

      return SizedBox(
        width: width.toDouble(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text.rich(bodySpan),
            Positioned(
              right: 0,
              bottom: 1,
              child: Text(time!, style: timeStyle),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(bodySpan),
        ),
        const SizedBox(height: 1),
        Text(time!, style: timeStyle),
      ],
    );
  }

  List<InlineSpan>? _mentionSpans({bool interactive = true}) {
    final valid = mentions.where((mention) => mention.matches(body)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final unique = <ChatMention>[];
    final seen = <String>{};
    for (final mention in valid) {
      final key = '${mention.start}:${mention.end}:${mention.displayText}';
      if (seen.add(key)) unique.add(mention);
    }
    if (unique.isEmpty) return null;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final mention in unique) {
      if (mention.start < cursor) continue;
      if (mention.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, mention.start)));
      }
      final mentionStyle = _bodyStyle.copyWith(
        color: chatMentionAccent,
        fontWeight: FontWeight.w800,
      );
      if (!interactive) {
        spans.add(TextSpan(text: mention.displayText, style: mentionStyle));
        cursor = mention.end;
        continue;
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          key: ValueKey(
            'chat-mention-${mention.isAll ? 'all' : mention.userId}-${mention.start}',
          ),
          onTap: mention.isAll || onMentionTap == null
              ? null
              : () => onMentionTap!(mention.userId),
          child: Text(
            mention.displayText,
            style: mentionStyle,
          ),
        ),
      ));
      cursor = mention.end;
    }
    if (cursor < body.length) spans.add(TextSpan(text: body.substring(cursor)));
    return spans;
  }
}

TextStyle _bubbleTimestampStyle() {
  return TextStyle(
    color: const Color(0xFF64748B).withValues(alpha: 0.82),
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1,
  );
}
