import 'dart:math' as math;

import 'package:flutter/material.dart';

EdgeInsets withNavigationClearance(
  BuildContext context,
  EdgeInsets insets, {
  double additionalBottom = 0,
}) {
  return insets.copyWith(
    bottom: math.max(
      insets.bottom,
      MediaQuery.paddingOf(context).bottom + additionalBottom,
    ),
  );
}
