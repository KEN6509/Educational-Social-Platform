import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const _avatarOutputSize = 512;

  late final img.Image _sourceImage;
  ui.Image? _previewImage;
  Offset _center = Offset.zero;
  double _zoom = 1;
  double _gestureStartZoom = 1;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) {
      throw StateError('Unable to decode selected profile image.');
    }
    _sourceImage = decoded;
    _center = Offset(
      _sourceImage.width / 2,
      _sourceImage.height / 2,
    );
    ui.decodeImageFromList(widget.imageBytes, (image) {
      if (mounted) setState(() => _previewImage = image);
    });
  }

  Rect _cropRect() {
    final cropSide = math.min(_sourceImage.width, _sourceImage.height) / _zoom;
    final half = cropSide / 2;
    final clampedCenter = Offset(
      _center.dx.clamp(half, _sourceImage.width - half).toDouble(),
      _center.dy.clamp(half, _sourceImage.height - half).toDouble(),
    );
    return Rect.fromCenter(
      center: clampedCenter,
      width: cropSide,
      height: cropSide,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double previewSize) {
    final cropSide = math.min(_sourceImage.width, _sourceImage.height) / _zoom;
    final sourceDelta = Offset(
      -details.focalPointDelta.dx / previewSize * cropSide,
      -details.focalPointDelta.dy / previewSize * cropSide,
    );
    setState(() {
      _zoom = (_gestureStartZoom * details.scale).clamp(1.0, 4.0).toDouble();
      _center += sourceDelta;
      _center = _clampedCenter();
    });
  }

  Offset _clampedCenter() {
    final cropSide = math.min(_sourceImage.width, _sourceImage.height) / _zoom;
    final half = cropSide / 2;
    return Offset(
      _center.dx.clamp(half, _sourceImage.width - half).toDouble(),
      _center.dy.clamp(half, _sourceImage.height - half).toDouble(),
    );
  }

  void _cropAndReturn() {
    final rect = _cropRect();
    final cropSide = rect.width.round();
    final cropped = img.copyCrop(
      _sourceImage,
      x: rect.left.round(),
      y: rect.top.round(),
      width: cropSide,
      height: cropSide,
    );
    final resized = img.copyResizeCropSquare(
      cropped,
      size: _avatarOutputSize,
    );
    Navigator.pop(
      context,
      Uint8List.fromList(img.encodeJpg(resized, quality: 88)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewImage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Crop photo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: preview == null ? null : _cropAndReturn,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = math.min(constraints.maxWidth, 360.0);
          return Column(
            children: [
              const Spacer(),
              Center(
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: (details) =>
                      _onScaleUpdate(details, previewSize),
                  child: ClipOval(
                    child: SizedBox(
                      width: previewSize,
                      height: previewSize,
                      child: preview == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : CustomPaint(
                              painter: _AvatarCropPainter(
                                image: preview,
                                sourceRect: _cropRect(),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Move and pinch to adjust',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarCropPainter extends CustomPainter {
  const _AvatarCropPainter({
    required this.image,
    required this.sourceRect,
  });

  final ui.Image image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    final destination = Offset.zero & size;
    canvas.drawImageRect(image, sourceRect, destination, Paint());
  }

  @override
  bool shouldRepaint(covariant _AvatarCropPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
  }
}
