import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class BottomSafeSurface extends StatelessWidget {
  const BottomSafeSurface({
    required this.child,
    this.color = AppColors.background,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: padding.copyWith(bottom: padding.bottom + safeBottom),
        child: child,
      ),
    );
  }
}
