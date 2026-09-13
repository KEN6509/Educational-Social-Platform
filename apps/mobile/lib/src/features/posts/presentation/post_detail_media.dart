part of 'post_detail_page.dart';

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
    AppFeedback.showError(context, 'Photo could not load');
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
        AppFeedback.showWarning(
          context,
          'Photo access is required to download images',
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
      AppFeedback.showSuccess(context, 'Photo downloaded');
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
