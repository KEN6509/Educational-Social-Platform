import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/chat_models.dart';
import '../data/chat_mention.dart';

const chatNavy = Color(0xFF0B1F3E);
const chatCyan = Color(0xFF4490AD);
const chatBackground = Color(0xFFFAFCFC);
const chatInput = Colors.white;
const chatBorder = Color(0xFFE2E8F0);
const chatDanger = Color(0xFFE11D48);
const chatWhatsappBackground = Color(0xFFECE5DD);
const chatMineBubble = Color(0xFFD9FDD3);
const chatOtherBubble = Colors.white;
const chatSoftGrey = Color(0xFFF8FAFC);
const chatPreviewBackground = Color(0xFFF1F3F5);
const chatMentionAccent = Color(0xFF128C7E);

const chatAppBarTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.2,
);

const chatSectionTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.1,
);

const _groupColors = [
  Color(0xFF2563EB),
  Color(0xFF0F766E),
  Color(0xFFF97316),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFDB2777),
];

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: chatDanger,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 46,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? 'C' : trimmed.characters.first.toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: chatCyan.withValues(alpha: 0.14),
      foregroundImage: avatarUrl == null || avatarUrl!.isEmpty
          ? null
          : NetworkImage(avatarUrl!),
      child: Text(
        initial,
        style: const TextStyle(
          color: chatNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatNoSplash extends StatelessWidget {
  const ChatNoSplash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.seed,
    this.size = 46,
  });

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _comfortableGroupColor(seed);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Icon(
        Icons.people_alt_rounded,
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

Color _comfortableGroupColor(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return _groupColors[hash % _groupColors.length];
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: chatInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

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
              borderRadius: BorderRadius.circular(8),
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

class _ImageBubbleContent extends StatelessWidget {
  const _ImageBubbleContent({
    required this.imageUrls,
    required this.imageAspectRatios,
    required this.time,
    required this.timeStyle,
    required this.maxWidth,
    required this.senderName,
    required this.sentAt,
    required this.isSelectionMode,
    required this.onSelectionTap,
  });

  final List<String> imageUrls;
  final List<double> imageAspectRatios;
  final String? time;
  final TextStyle timeStyle;
  final double maxWidth;
  final String senderName;
  final DateTime? sentAt;
  final bool isSelectionMode;
  final VoidCallback? onSelectionTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxThumbnailHeight = math.min(520.0, size.height * 0.6);
    final width = imageUrls.length == 1
        ? maxWidth
        : math.min(maxWidth, maxThumbnailHeight);
    final height = _gridHeight(width, imageUrls.length);
    final heroTag = 'chat-image-${imageUrls.first}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelectionMode) {
          onSelectionTap?.call();
          return;
        }
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: false,
            barrierColor: Colors.white,
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: _ChatImagePreviewPage(
                imageUrls: imageUrls,
                initialIndex: 0,
                heroTag: heroTag,
                senderName: senderName,
                sentAt: sentAt,
                showAllImages: imageUrls.length > 1,
              ),
            ),
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: imageUrls.length == 1
              ? _SingleImageBubbleThumbnail(
                  imageUrl: imageUrls.first,
                  width: width,
                  maxHeight: maxThumbnailHeight,
                  time: time,
                  timeStyle: timeStyle,
                )
              : SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ImageBubbleGrid(
                        imageUrls: imageUrls,
                        imageAspectRatios: imageAspectRatios,
                        onTapImage: (index) {
                          if (isSelectionMode) {
                            onSelectionTap?.call();
                            return;
                          }
                          _openPreview(
                            context,
                            imageUrls,
                            index,
                            'chat-image-${imageUrls[index]}',
                            showAllImages: imageUrls.length > 1,
                          );
                        },
                      ),
                      if (time != null)
                        Positioned(
                          right: 7,
                          bottom: 6,
                          child: _ImageTimePill(
                            time: time!,
                            timeStyle: timeStyle,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  double _gridHeight(double width, int count) {
    if (count == 2) return (width - 4) / 2;
    if (count == 3) {
      const gap = 4.0;
      final cell = (width - gap) / 2;
      return cell * 2 + gap;
    }
    final visibleCount = math.min(count, 4);
    final rows = (visibleCount / 2).ceil();
    const gap = 4.0;
    final cell = (width - gap) / 2;
    return rows * cell + (rows - 1) * gap;
  }

  void _openPreview(
      BuildContext context, List<String> urls, int index, String heroTag,
      {required bool showAllImages}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.white,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ChatImagePreviewPage(
            imageUrls: urls,
            initialIndex: index,
            heroTag: heroTag,
            senderName: senderName,
            sentAt: sentAt,
            showAllImages: showAllImages,
          ),
        ),
      ),
    );
  }
}

class _SingleImageBubbleThumbnail extends StatefulWidget {
  const _SingleImageBubbleThumbnail({
    required this.imageUrl,
    required this.width,
    required this.maxHeight,
    required this.time,
    required this.timeStyle,
  });

  final String imageUrl;
  final double width;
  final double maxHeight;
  final String? time;
  final TextStyle timeStyle;

  @override
  State<_SingleImageBubbleThumbnail> createState() =>
      _SingleImageBubbleThumbnailState();
}

class _SingleImageBubbleThumbnailState
    extends State<_SingleImageBubbleThumbnail> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _SingleImageBubbleThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = null;
      _resolveImage();
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    super.dispose();
  }

  void _resolveImage() {
    final oldListener = _listener;
    if (oldListener != null) {
      _stream?.removeListener(oldListener);
    }
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (width <= 0 || height <= 0 || !mounted) return;
      setState(() => _aspectRatio = width / height);
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (_aspectRatio ?? 1).clamp(0.75, 2.35).toDouble();
    final maxDisplayWidth =
        aspectRatio < 0.9 ? widget.width * 0.84 : widget.width;
    final naturalHeight = maxDisplayWidth / aspectRatio;
    final displayHeight = math.min(naturalHeight, widget.maxHeight);
    final displayWidth = displayHeight == naturalHeight
        ? maxDisplayWidth
        : displayHeight * aspectRatio;

    return SizedBox(
      width: displayWidth,
      height: displayHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _ChatImageThumbnailLoadError(),
          ),
          if (widget.time != null)
            Positioned(
              right: 7,
              bottom: 6,
              child: _ImageTimePill(
                time: widget.time!,
                timeStyle: widget.timeStyle,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageTimePill extends StatelessWidget {
  const _ImageTimePill({
    required this.time,
    required this.timeStyle,
  });

  final String time;
  final TextStyle timeStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        child: Text(
          time,
          style: timeStyle.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _ChatImagePreviewPage extends StatefulWidget {
  const _ChatImagePreviewPage({
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTag,
    required this.senderName,
    required this.sentAt,
    required this.showAllImages,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String heroTag;
  final String senderName;
  final DateTime? sentAt;
  final bool showAllImages;

  @override
  State<_ChatImagePreviewPage> createState() => _ChatImagePreviewPageState();
}

class _ChatImagePreviewPageState extends State<_ChatImagePreviewPage> {
  late final PageController _pageController;
  late int _index;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _subtitle {
    final countLabel = widget.imageUrls.length == 1
        ? '1 photo'
        : '${widget.imageUrls.length} photos';
    final sent = widget.sentAt == null
        ? ''
        : ' · ${_formatPreviewDateTime(widget.sentAt!)}';
    return '$countLabel$sent';
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
        : 'chat-photo.jpg';
    final cleanName = pathName.split('?').first.trim();
    if (cleanName.isEmpty) return 'chat-photo.jpg';
    if (cleanName.contains('.')) return cleanName;
    return '$cleanName.jpg';
  }

  void _openFullImage(int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ChatImagePreviewPage(
            imageUrls: widget.imageUrls,
            initialIndex: index,
            heroTag: 'chat-image-${widget.imageUrls[index]}',
            senderName: widget.senderName,
            sentAt: widget.sentAt,
            showAllImages: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatPreviewBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: chatNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.showAllImages)
            IconButton(
              tooltip: 'Download',
              onPressed: _downloadCurrentImage,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: widget.showAllImages ? _buildAllImages() : _buildSingleImagePager(),
    );
  }

  Widget _buildAllImages() {
    return ListView.separated(
      key: const ValueKey('chat-image-preview-light-list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widget.imageUrls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullImage(index),
          behavior: HitTestBehavior.opaque,
          child: Image.network(
            widget.imageUrls[index],
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) {
              return const SizedBox(
                height: 260,
                child: Center(child: _ChatImageLoadError()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSingleImagePager() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (context, index) {
        final image = InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.imageUrls[index],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const _ChatImageLoadError(compact: true);
              },
            ),
          ),
        );
        if (index == widget.initialIndex) {
          return Hero(tag: widget.heroTag, child: image);
        }
        return image;
      },
    );
  }
}

class _ChatImageLoadError extends StatelessWidget {
  const _ChatImageLoadError({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: compact ? 220 : double.infinity,
        child: const Text(
          'Photo could not load',
          textAlign: TextAlign.center,
          style: TextStyle(
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

class _ImageBubbleGrid extends StatelessWidget {
  const _ImageBubbleGrid({
    required this.imageUrls,
    required this.imageAspectRatios,
    required this.onTapImage,
  });

  final List<String> imageUrls;
  final List<double> imageAspectRatios;
  final ValueChanged<int> onTapImage;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return _GridImage(url: imageUrls.first, onTap: () => onTapImage(0));
    }

    if (imageUrls.length == 2) {
      return Row(
        children: [
          Expanded(
              child: _GridImage(url: imageUrls[0], onTap: () => onTapImage(0))),
          const SizedBox(width: 4),
          Expanded(
              child: _GridImage(url: imageUrls[1], onTap: () => onTapImage(1))),
        ],
      );
    }

    if (imageUrls.length == 3) {
      final firstRatio =
          imageAspectRatios.isEmpty ? 0.75 : imageAspectRatios.first;
      if (firstRatio < 1) {
        return Row(
          children: [
            Expanded(
              child: SizedBox.expand(
                key: const ValueKey('chat-image-tall-left-first'),
                child:
                    _GridImage(url: imageUrls[0], onTap: () => onTapImage(0)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      key: const ValueKey('chat-image-right-top-square'),
                      child: _GridImage(
                        url: imageUrls[1],
                        onTap: () => onTapImage(1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SizedBox.expand(
                      key: const ValueKey('chat-image-right-bottom-square'),
                      child: _GridImage(
                        url: imageUrls[2],
                        onTap: () => onTapImage(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          Expanded(
            child: SizedBox.expand(
              key: const ValueKey('chat-image-top-wide-first'),
              child: _GridImage(url: imageUrls[0], onTap: () => onTapImage(0)),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    key: const ValueKey('chat-image-bottom-left-square'),
                    child: _GridImage(
                      url: imageUrls[1],
                      onTap: () => onTapImage(1),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox.expand(
                    key: const ValueKey('chat-image-bottom-right-square'),
                    child: _GridImage(
                      url: imageUrls[2],
                      onTap: () => onTapImage(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final visibleCount = math.min(imageUrls.length, 4);
    final overflow = imageUrls.length - visibleCount;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: visibleCount,
      itemBuilder: (context, index) {
        final showOverlay = index == visibleCount - 1 && overflow > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            _GridImage(
              url: imageUrls[index],
              onTap: () => onTapImage(index),
            ),
            if (showOverlay)
              GestureDetector(
                onTap: () => onTapImage(index),
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.48),
                  child: Center(
                    child: Text(
                      '+$overflow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridImage extends StatelessWidget {
  const _GridImage({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ChatImageThumbnailLoadError(),
      ),
    );
  }
}

class _ChatImageThumbnailLoadError extends StatelessWidget {
  const _ChatImageThumbnailLoadError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFCBD5E1),
          size: 24,
        ),
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

class ChatAvatarWithBadge extends StatelessWidget {
  const ChatAvatarWithBadge({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.count,
    this.size = 46,
  });

  final String name;
  final String? avatarUrl;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChatAvatar(name: name, avatarUrl: avatarUrl, size: size),
        if (count > 0)
          Positioned(
            right: -2,
            top: -4,
            child: UnreadBadge(count: count),
          ),
      ],
    );
  }
}

class ConversationTile extends StatefulWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final avatar = conversation.isGroup
        ? GroupAvatar(
            seed: conversation.id,
            size: 54,
          )
        : ChatAvatar(
            name: conversation.displayTitle,
            avatarUrl: conversation.otherUserAvatarUrl,
            size: 54,
          );
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: _pressed ? const Color(0xFFF8FAFC) : Colors.transparent,
        padding: const EdgeInsets.only(left: 18),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 13, 16, 13),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: chatNavy,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _formatChatTime(conversation.lastMessageAt),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _ConversationPreviewLine(
                      body: conversation.lastMessageBody,
                      fallback: conversation.isRequest
                          ? 'Message request'
                          : !conversation.isGroup &&
                                  !conversation.canSendMessages
                              ? 'Follow this user to continue chatting.'
                              : 'Start chatting',
                      unreadCount: conversation.unreadCount,
                      hasMention: conversation.hasUnvisitedMention,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationPreviewLine extends StatelessWidget {
  const _ConversationPreviewLine({
    required this.body,
    required this.fallback,
    required this.unreadCount,
    required this.hasMention,
  });

  final String? body;
  final String fallback;
  final int unreadCount;
  final bool hasMention;

  @override
  Widget build(BuildContext context) {
    final value = body?.trim();
    final hasImage = value != null && ChatMessage.bodyHasImage(value);
    final text = value == null || value.isEmpty
        ? fallback
        : ChatMessage.displayBodyFor(value);
    final textStyle = const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    if (!hasImage) {
      return Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          if (hasMention || unreadCount > 0) const SizedBox(width: 8),
          if (hasMention) ...[
            const _ConversationMentionIndicator(),
            if (unreadCount > 0) const SizedBox(width: 6),
          ],
          if (unreadCount > 0) UnreadBadge(count: unreadCount),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.image_outlined,
          size: 15,
          color: Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        if (hasMention || unreadCount > 0) const SizedBox(width: 8),
        if (hasMention) ...[
          const _ConversationMentionIndicator(),
          if (unreadCount > 0) const SizedBox(width: 6),
        ],
        if (unreadCount > 0) UnreadBadge(count: unreadCount),
      ],
    );
  }
}

class _ConversationMentionIndicator extends StatelessWidget {
  const _ConversationMentionIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('conversation-mention-indicator'),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: chatMentionAccent,
        shape: BoxShape.circle,
      ),
      child: Transform.translate(
        key: const ValueKey('conversation-mention-glyph'),
        offset: const Offset(0, -2),
        child: const Text(
          '@',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class ChatParticipantRow extends StatelessWidget {
  const ChatParticipantRow({
    super.key,
    required this.participant,
    this.onTap,
    this.trailing,
    this.showAdmin = false,
    this.contentPadding = EdgeInsets.zero,
  });

  final ChatParticipant participant;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAdmin;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final action =
        showAdmin && participant.isAdmin ? const _AdminBadge() : trailing;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            ChatAvatar(
              name: participant.name,
              avatarUrl: participant.avatarUrl,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                participant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: chatNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              _ParticipantActionSlot(child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantActionSlot extends StatelessWidget {
  const _ParticipantActionSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: chatCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Admin',
        style: TextStyle(
          color: chatCyan,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatNoResultsState extends StatelessWidget {
  const ChatNoResultsState({
    super.key,
    this.title = 'No results found',
    this.subtitle = 'Try another search',
    this.subtitleWidget,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String subtitle;
  final Widget? subtitleWidget;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xFF94A3B8), size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            subtitleWidget ??
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: chatCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: chatCyan, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBubbleTime(DateTime value) {
  final local = value.toLocal();
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hourValue = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final hour = hourValue.toString();
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

String _formatPreviewDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year} ${_formatBubbleTime(local)}';
}

String _formatChatTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return _formatBubbleTime(local);
  }
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return _weekdayLabel(local.weekday);
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
  }
}

class NotificationEntryCard extends StatelessWidget {
  const NotificationEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 178,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chatBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: chatCyan),
                const Spacer(),
                UnreadBadge(count: count),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: chatNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
