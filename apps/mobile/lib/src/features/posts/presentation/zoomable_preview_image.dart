import 'package:flutter/material.dart';

/// Shared zoom and pan behavior for published and draft post images.
class ZoomablePreviewImage extends StatefulWidget {
  const ZoomablePreviewImage({
    required this.image,
    required this.onTap,
    required this.onZoomOut,
    this.onZoomChanged,
    this.errorPlaceholder,
    super.key,
  });

  final ImageProvider image;
  final VoidCallback onTap;
  final VoidCallback onZoomOut;
  final ValueChanged<bool>? onZoomChanged;
  final Widget? errorPlaceholder;

  @override
  State<ZoomablePreviewImage> createState() => _ZoomablePreviewImageState();
}

class _ZoomablePreviewImageState extends State<ZoomablePreviewImage>
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
            setState(() => _canPanImage = canPanImage);
          }
          widget.onZoomChanged?.call(canPanImage);
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
          child: Image(
            image: widget.image,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                widget.errorPlaceholder ??
                const Icon(Icons.broken_image_outlined, color: Colors.white70),
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
