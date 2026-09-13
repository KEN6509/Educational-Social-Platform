import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CyanZone colour tokens keep the approved palette', () {
    expect(AppColors.cyan.toARGB32(), 0xFF4490AD);
    expect(AppColors.navy.toARGB32(), 0xFF0B1F3E);
    expect(AppColors.background.toARGB32(), 0xFFFAFCFC);
    expect(AppColors.surface.toARGB32(), 0xFFFFFFFF);
    expect(AppColors.textPrimary.toARGB32(), 0xFF0F172A);
    expect(AppColors.textSecondary.toARGB32(), 0xFF64748B);
    expect(AppColors.error.toARGB32(), 0xFFE11D48);
  });

  test('spacing and floating navigation tokens keep the approved geometry', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 12);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.page, 20);
    expect(AppSpacing.section, 24);
    expect(AppSpacing.xl, 32);
    expect(AppInsets.page.horizontal, 40);
    expect(AppRadii.dialog, 22);
    expect(AppRadii.navigation, 28);
    expect(AppLayout.floatingNavigationHeight, 62);
    expect(AppLayout.floatingNavigationClearance, 86);
  });

  test('AppTheme exposes CyanZone semantic component styling', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.cyan);
    expect(theme.colorScheme.surface, AppColors.background);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.backgroundColor, AppColors.surface);
    expect(theme.snackBarTheme.actionTextColor, AppColors.cyan);
    expect(theme.snackBarTheme.disabledActionTextColor, AppColors.textMuted);
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
  });
}
