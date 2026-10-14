import 'package:flutter/material.dart';

/// EcoTag's shared color palette.
///
/// Product colors belong here so screens and reusable widgets do not need to
/// carry private copies of the same green, border, or state colors.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF4F8F5);

  static const Color surface = Colors.white;

  /// A quiet surface used for search fields, filters, and secondary regions.
  static const Color surfaceVariant = Color(0xFFF1F8F1);

  /// A neutral surface for disabled and read-only inputs.
  static const Color surfaceDisabled = Color(0xFFF0F2F0);

  static const Color surfaceSubtle = Color(0xFFF8FBF9);

  // Dark enough to meet WCAG AA when used for normal-sized text on white.
  static const Color green = Color(0xFF117A3D);

  static const Color primary = Color(0xFF2E7D32);

  static const Color primaryLight = Color(0xFF43A047);

  static const Color primaryContainer = Color(0xFFE8F5E9);

  static const Color secondary = Color(0xFF00796B);

  static const Color secondaryContainer = Color(0xFFE0F2F1);

  static const Color darkGreen = Color(0xFF075E38);

  static const Color border = Color(0xFFDCE8DF);

  static const Color borderStrong = Color(0xFFC7D8CB);

  static const Color navbarBorder = Color(0xFFE5ECE7);

  static const Color textPrimary = Color(0xFF1A2E1A);

  static const Color textSecondary = Color(0xFF56665B);

  static const Color textDisabled = Color(0xFF8B948E);

  static const Color inactiveNav = Color(0xFF626B65);

  static const Color healthy = Color(0xFF43A047);

  static const Color warning = Color(0xFF9A5B00);

  static const Color warningAccent = Color(0xFFF59E0B);

  static const Color warningContainer = Color(0xFFFFF3DC);

  static const Color warningBorder = Color(0xFFFFD591);

  static const Color danger = Color(0xFFC62828);

  static const Color dangerContainer = Color(0xFFFDE7E9);

  static const Color info = Color(0xFF1976D2);

  static const Color infoContainer = Color(0xFFE8F0FE);

  static const Color accentPurple = Color(0xFF7C3AED);

  static const Color accentPurpleContainer = Color(0xFFF1EAFE);

  /// Accent used to call attention to filter and refinement controls.
  static const Color filterAccent = warningAccent;

  /// Shared chart colors keep analytics and status legends consistent.
  static const Color chartHealthy = healthy;
  static const Color chartAtRisk = Color(0xFFFF9800);
  static const Color chartDead = Color(0xFFE53935);
  static const Color chartUnknown = Color(0xFF78909C);

  static const Color onPrimary = Colors.white;

  static const Color cardShadow = Color(0x0F075E38);

  static const Color softShadow = Color(0x11000000);

  /// Dark surfaces used over the photographic public landing page.
  static const Color heroOverlayDark = Color(0xFF092E21);
  static const Color heroOverlay = Color(0xFF102D20);
  static const Color heroOverlayStrong = Color(0xFF062F20);
  static const Color heroMuted = Color(0xFFDDEBE2);
  static const Color heroMutedAlt = Color(0xFFE3EEE7);
  static const Color heroSurface = Color(0xFFF2F7F3);

  /// Neutral camera surface shared by authenticated and guest scanners.
  static const Color scannerBackground = Color(0xFF101713);
}
