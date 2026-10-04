import 'package:flutter/material.dart';

import 'zoomable_preview_image.dart';

/// Full-screen review of images selected for a post, without changing the draft.
class DraftImagePreviewPage extends StatefulWidget {
  const DraftImagePreviewPage({
    required this.images,
    required this.initialIndex,
    super.key,
  }) : assert(images.length > 0);

  final List<ImageProvider> images;
  final int initialIndex;

  @override
  State<DraftImagePreviewPage> createState() => _DraftImagePreviewPageState();
}

class _DraftImagePreviewPageState extends State<DraftImagePreviewPage> {
  late final PageController _controller;
  late int _index;
  bool _isCurrentImageZoomed = false;
  int? _swipePointer;
  Offset? _swipeStart;
  bool _multiTouch = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _showAdjacentImage(int direction) {
    if (_isCurrentImageZoomed) return;
    final next = _index + direction;
    if (next < 0 || next >= widget.images.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (_swipePointer == null) {
                    _swipePointer = event.pointer;
                    _swipeStart = event.position;
                    _multiTouch = false;
                  } else {
                    _multiTouch = true;
                  }
                },
                onPointerUp: (event) {
                  if (event.pointer != _swipePointer) return;
                  final start = _swipeStart;
                  _swipePointer = null;
                  _swipeStart = null;
                  if (_multiTouch || _isCurrentImageZoomed || start == null) {
                    return;
                  }
                  final delta = event.position - start;
                  if (delta.dx.abs() > 70 &&
                      delta.dx.abs() > delta.dy.abs() * 1.5) {
                    _showAdjacentImage(delta.dx < 0 ? 1 : -1);
                  }
                },
                onPointerCancel: (_) {
                  _swipePointer = null;
                  _swipeStart = null;
                },
                child: PageView.builder(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.images.length,
                  onPageChanged: (value) => setState(() {
                    _index = value;
                    _isCurrentImageZoomed = false;
                  }),
                  itemBuilder: (context, index) => ZoomablePreviewImage(
                    image: widget.images[index],
                    onTap: _close,
                    onZoomOut: _close,
                    onZoomChanged: index == _index
                        ? (isZoomed) {
                            if (_isCurrentImageZoomed != isZoomed) {
                              setState(() => _isCurrentImageZoomed = isZoomed);
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close preview',
                        onPressed: _close,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          '${_index + 1}/${widget.images.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
