part of 'chat_widgets.dart';

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
