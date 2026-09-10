import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cyan = Color(0xFF4490AD);
  static const navy = Color(0xFF0B1F3E);
  static const mint = Color(0xFF58E1B5);
  static const background = Color(0xFFFAFCFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFE11D48);
  static const disabled = Color(0xFFB9C9D1);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 20.0;
  static const section = 24.0;
  static const xl = 32.0;
}

abstract final class AppInsets {
  static const page = EdgeInsets.symmetric(horizontal: AppSpacing.page);
  static const compact = EdgeInsets.all(AppSpacing.md);
  static const component = EdgeInsets.all(AppSpacing.lg);
  static const snackbar = EdgeInsets.fromLTRB(16, 0, 16, 18);
}

abstract final class AppRadii {
  static const compact = 14.0;
  static const control = 18.0;
  static const dialog = 22.0;
  static const navigation = 28.0;
}

abstract final class AppLayout {
  static const floatingNavigationHeight = 62.0;
  static const floatingNavigationOuterMargin = 12.0;
  static const floatingNavigationClearance = 86.0;
}
