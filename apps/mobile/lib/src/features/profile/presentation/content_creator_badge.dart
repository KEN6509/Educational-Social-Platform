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

    return SizedBox(
      key: const ValueKey('verified-creator-rosette'),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.verified_rounded,
            color: const Color(0xFF4490AD),
            size: size,
          ),
          Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: size * 0.58,
          ),
        ],
      ),
    );
  }
}
