import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Widths used to choose an intentional phone, tablet, or desktop layout.
class AppBreakpoints {
  AppBreakpoints._();

  static const double phone = 600;
  static const double desktop = 900;

  static bool isPhone(double width) => width < phone;

  static bool isTablet(double width) => width >= phone && width < desktop;

  static bool isDesktop(double width) => width >= desktop;
}

/// The only spacing steps used by shared EcoTag UI.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Shared corner radii for controls, cards, and large surfaces.
class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullyRounded = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Shared borders used by cards and interactive controls.
class AppBorders {
  AppBorders._();

  static const BorderSide subtleSide = BorderSide(color: AppColors.border);
  static const BorderSide strongSide = BorderSide(
    color: AppColors.borderStrong,
  );
  static const BorderSide focusedSide = BorderSide(
    color: AppColors.primary,
    width: 1.5,
  );
  static const BorderSide errorSide = BorderSide(color: AppColors.danger);

  static const Border subtle = Border.fromBorderSide(subtleSide);
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.cardShadow,
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

/// Shared dimensions and helpers for page-level responsive layout.
class AppLayout {
  AppLayout._();

  static const double maxContentWidth = 1520;
  static const double minimumTapTarget = 48;

  static EdgeInsets pagePadding(double width) {
    return EdgeInsets.all(
      AppBreakpoints.isPhone(width) ? AppSpacing.lg : AppSpacing.xl,
    );
  }

  static double sectionGap(double width) {
    return AppSpacing.lg;
  }

  static BoxConstraints get contentConstraints =>
      const BoxConstraints(maxWidth: maxContentWidth);
}
