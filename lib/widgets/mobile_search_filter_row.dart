import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Shared mobile search field height so every screen's search matches.
const double kMobileSearchVerticalPadding = 18;
const double kMobileFilterButtonSize = 60;

/// Search field with the filter icon beside it, used on every mobile list.
class MobileSearchFilterRow extends StatelessWidget {
  final Widget search;
  final VoidCallback onFilter;
  final int activeCount;

  const MobileSearchFilterRow({
    super.key,
    required this.search,
    required this.onFilter,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: search),
      const SizedBox(width: AppSpacing.md),
      IconButton(
        onPressed: onFilter,
        tooltip: 'Filters',
        style: IconButton.styleFrom(
          fixedSize: const Size.square(kMobileFilterButtonSize),
          foregroundColor: AppColors.darkGreen,
          backgroundColor: activeCount > 0
              ? AppColors.primaryContainer
              : AppColors.surface,
          side: BorderSide(
            color: activeCount > 0 ? AppColors.green : AppColors.border,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
        ),
        icon: Badge(
          isLabelVisible: activeCount > 0,
          label: Text('$activeCount'),
          child: const Icon(Icons.tune_rounded, size: 24),
        ),
      ),
    ],
  );
}
