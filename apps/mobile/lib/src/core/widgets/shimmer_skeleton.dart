import 'package:flutter/material.dart';

class ShimmerBlock extends StatefulWidget {
  const ShimmerBlock({
    required this.width,
    required this.height,
    required this.radius,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
              colors: const [
                Color(0xFFEFF4F6),
                Color(0xFFF9FCFD),
                Color(0xFFEFF4F6),
              ],
              stops: const [0.22, 0.5, 0.78],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4F6),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: SizedBox(width: widget.width, height: widget.height),
      ),
    );
  }
}
