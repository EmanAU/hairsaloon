import 'package:flutter/material.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

/// Compact Material 3 theme. System font scaling is locked in [BusinessCombApp].
class AppTheme {
  const AppTheme._();

  static const double textScaleFactor = 1.0;

  static TextTheme _compactTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 48),
      displayMedium: base.displayMedium?.copyWith(fontSize: 40),
      displaySmall: base.displaySmall?.copyWith(fontSize: 32),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 26),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 22),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 18),
      titleLarge: base.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 14),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: base.bodySmall?.copyWith(fontSize: 11),
      labelLarge: base.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontSize: 11),
      labelSmall: base.labelSmall?.copyWith(fontSize: 10),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: _compactTextTheme(base.textTheme),
      primaryTextTheme: _compactTextTheme(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
