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
    // Brand yellow stays on [AppColors.primary] for surfaces/headers.
    // ColorScheme.primary is black so Material text/icons are never yellow.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.textPrimary,
      onPrimary: AppColors.surface,
      secondary: AppColors.primary,
      onSecondary: AppColors.onPrimary,
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
      primaryTextTheme: _compactTextTheme(base.primaryTextTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        floatingLabelStyle: TextStyle(color: AppColors.textPrimary),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        selectedIconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(
          color: AppColors.textSecondary,
          size: 22,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return null;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.surface),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textSecondary;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Color(0x00000000),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}
