import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'EcoTagRoboto';
  static const EdgeInsets controlPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
  static const RoundedRectangleBorder controlShape = RoundedRectangleBorder(
    borderRadius: AppRadii.medium,
  );
  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: AppRadii.large,
    side: AppBorders.subtleSide,
  );
  static const OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: AppRadii.medium,
    borderSide: AppBorders.subtleSide,
  );
  static const OutlineInputBorder focusedInputBorder = OutlineInputBorder(
    borderRadius: AppRadii.medium,
    borderSide: AppBorders.focusedSide,
  );
  static const OutlineInputBorder errorInputBorder = OutlineInputBorder(
    borderRadius: AppRadii.medium,
    borderSide: AppBorders.errorSide,
  );
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
      headlineSmall: _compactStyle(
        theme.headlineSmall,
      ).copyWith(fontSize: AppTypography.pageTitle),
      titleLarge: _compactStyle(
        theme.titleLarge,
      ).copyWith(fontSize: AppTypography.sectionTitle),
      titleMedium: _compactStyle(
        theme.titleMedium,
      ).copyWith(fontSize: AppTypography.itemTitle),
      titleSmall: _compactStyle(
        theme.titleSmall,
      ).copyWith(fontSize: AppTypography.itemTitle),
      bodyLarge: _compactStyle(
        theme.bodyLarge,
      ).copyWith(fontSize: AppTypography.body),
      bodyMedium: _compactStyle(
        theme.bodyMedium,
      ).copyWith(fontSize: AppTypography.body),
      bodySmall: _compactStyle(
        theme.bodySmall,
      ).copyWith(fontSize: AppTypography.caption),
      labelLarge: _compactStyle(
        theme.labelLarge,
      ).copyWith(fontSize: AppTypography.label),
      labelMedium: _compactStyle(
        theme.labelMedium,
      ).copyWith(fontSize: AppTypography.caption),
      labelSmall: _compactStyle(
        theme.labelSmall,
      ).copyWith(fontSize: AppTypography.caption),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      error: AppColors.danger,
      outline: AppColors.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
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
          fontSize: AppTypography.sectionTitle,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyMedium: compactTextTheme.bodyMedium?.copyWith(
          fontSize: AppTypography.body,
          color: AppColors.textPrimary,
        ),
        bodySmall: compactTextTheme.bodySmall?.copyWith(
          fontSize: AppTypography.caption,
          color: AppColors.textSecondary,
        ),
      ),
      primaryTextTheme: _compactTextTheme(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: AppTypography.pageTitle,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 0,
          wordSpacing: 0,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.cardShadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(
            AppLayout.minimumTapTarget,
            AppLayout.minimumTapTarget,
          ),
          padding: controlPadding,
          shape: controlShape,
          textStyle: compactTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(
            AppLayout.minimumTapTarget,
            AppLayout.minimumTapTarget,
          ),
          padding: controlPadding,
          shape: controlShape,
          textStyle: compactTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(
            AppLayout.minimumTapTarget,
            AppLayout.minimumTapTarget,
          ),
          padding: controlPadding,
          side: AppBorders.subtleSide,
          shape: controlShape,
          textStyle: compactTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(
            AppLayout.minimumTapTarget,
            AppLayout.minimumTapTarget,
          ),
          padding: controlPadding,
          shape: controlShape,
          textStyle: compactTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.inactiveNav,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size.square(AppLayout.minimumTapTarget),
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: TextStyle(
          color: AppColors.darkGreen,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppColors.textSecondary),
        helperStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.inactiveNav,
        suffixIconColor: AppColors.inactiveNav,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.extraLarge),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.onPrimary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.border,
      ),
    );
  }
}
