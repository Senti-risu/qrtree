import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF43A047);
  static const primaryContainer = Color(0xFFE8F5E9);
  static const secondary = Color(0xFF00796B);
  static const secondaryContainer = Color(0xFFE0F2F1);
  static const background = Color(0xFFF0F7F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F8F1);
  static const onSurface = Color(0xFF1A2E1A);
  static const onSurfaceVariant = Color(0xFF5A7A5C);
  static const outline = Color(0xFFD8EAD8);
  static const healthy = Color(0xFF43A047);
  static const healthyContainer = Color(0xFFE8F5E9);
  static const warning = Color(0xFFFFB300);
  static const warningContainer = Color(0xFFFFF8E1);
  static const danger = Color(0xFFE53935);
  static const dangerContainer = Color(0xFFFFEBEE);
  static const info = Color(0xFF1976D2);
  static const infoContainer = Color(0xFFE3F2FD);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.nunito(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
        ),
        displayMedium: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineLarge: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineMedium: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceVariant,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
        color: AppColors.surface,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets pagePadding = EdgeInsets.all(24);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(20));
}
