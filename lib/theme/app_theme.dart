import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'EcoTagRoboto';
  static const List<FontFeature> _compactFontFeatures = [
    FontFeature.proportionalFigures(),
  ];

  static TextStyle _compactStyle(TextStyle? style) {
    return (style ?? const TextStyle()).copyWith(
      fontFamily: fontFamily,
      letterSpacing: 0,
      wordSpacing: 0,
      fontFeatures: _compactFontFeatures,
    );
  }

  static TextTheme _compactTextTheme(TextTheme theme) {
    return theme.copyWith(
      displayLarge: _compactStyle(theme.displayLarge),
      displayMedium: _compactStyle(theme.displayMedium),
      displaySmall: _compactStyle(theme.displaySmall),
      headlineLarge: _compactStyle(theme.headlineLarge),
      headlineMedium: _compactStyle(theme.headlineMedium),
      headlineSmall: _compactStyle(theme.headlineSmall),
      titleLarge: _compactStyle(theme.titleLarge),
      titleMedium: _compactStyle(theme.titleMedium),
      titleSmall: _compactStyle(theme.titleSmall),
      bodyLarge: _compactStyle(theme.bodyLarge),
      bodyMedium: _compactStyle(theme.bodyMedium),
      bodySmall: _compactStyle(theme.bodySmall),
      labelLarge: _compactStyle(theme.labelLarge),
      labelMedium: _compactStyle(theme.labelMedium),
      labelSmall: _compactStyle(theme.labelSmall),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final compactTextTheme = _compactTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: compactTextTheme.copyWith(
        headlineLarge: compactTextTheme.headlineLarge?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        headlineMedium: compactTextTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: compactTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyMedium: compactTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        bodySmall: compactTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      primaryTextTheme: _compactTextTheme(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}
