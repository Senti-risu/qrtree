import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

class InspectionOverviewMetric {
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onPressed;

  const InspectionOverviewMetric({
    required this.label,
    required this.count,
    required this.icon,
    required this.onPressed,
  });
}

/// The parent supplies its actual column width so this also supports the
/// dashboard's intrinsic equal-height row without nested LayoutBuilders.
class InspectionOverviewCard extends StatelessWidget {
  final double availableWidth;
  final List<InspectionOverviewMetric> metrics;
  final String lastInspection;
  final String message;
  final List<Widget> actions;

  const InspectionOverviewCard({
    super.key,
    required this.availableWidth,
    required this.metrics,
    required this.lastInspection,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final innerWidth =
        (availableWidth - 2 * (AppSpacing.lg + AppBorders.subtleSide.width))
            .clamp(0.0, double.infinity);
    final split =
        innerWidth >= 300 && MediaQuery.textScalerOf(context).scale(1) < 1.4;
    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Inspection Overview',
            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _fillRows(
            metrics.map((metric) => _metric(context, metric)).toList(),
            innerWidth,
            split,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: const ValueKey('last-inspection-row'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadii.medium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 20,
                  color: AppColors.green,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    lastInspection,
                    style: const TextStyle(
                      fontSize: AppTypography.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: const TextStyle(
              fontSize: AppTypography.body,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _fillRows(actions, innerWidth, split),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, InspectionOverviewMetric metric) =>
      OutlinedButton(
        onPressed: metric.onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceSubtle,
          padding: const EdgeInsets.all(AppSpacing.sm),
          alignment: Alignment.centerLeft,
          minimumSize: const Size(48, 64),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metric.icon, size: 19),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    metric.label,
                    style: const TextStyle(fontSize: AppTypography.body),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${metric.count}',
              style: const TextStyle(
                fontSize: AppTypography.metric,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
      );

  Widget _fillRows(List<Widget> children, double width, bool split) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (var index = 0; index < children.length; index++)
        SizedBox(
          width:
              split && !(index == children.length - 1 && children.length.isOdd)
              ? (width - AppSpacing.sm) / 2
              : width,
          child: children[index],
        ),
    ],
  );
}
