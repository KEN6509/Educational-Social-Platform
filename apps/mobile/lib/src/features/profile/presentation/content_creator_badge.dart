import 'package:flutter/material.dart';

class ContentCreatorBadge extends StatelessWidget {
  const ContentCreatorBadge({
    required this.isVisible,
    this.size = 14,
    super.key,
  });

  final bool isVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2F8FED),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: size * 0.78,
      ),
    );
  }
}
