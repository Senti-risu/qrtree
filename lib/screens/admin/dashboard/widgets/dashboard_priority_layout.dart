import 'package:flutter/material.dart';
import '../../../../theme/app_layout.dart';
import '../../../../widgets/equal_height_cards.dart';

/// Summary metrics lead, followed by inspection/health overviews and analytics.
class DashboardSummaryLayout extends StatelessWidget {
  const DashboardSummaryLayout({
    super.key,
    required this.stats,
    required this.analytics,
    this.overview,
    this.priority,
    this.trailing,
  });
  final Widget stats, analytics;
  final Widget? overview, priority, trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      stats,
      const SizedBox(height: AppSpacing.lg),
      if (overview != null) ...[
        overview!,
        const SizedBox(height: AppSpacing.lg),
      ],
      if (priority != null) ...[
        priority!,
        const SizedBox(height: AppSpacing.lg),
      ],
      analytics,
      if (trailing != null) ...[
        const SizedBox(height: AppSpacing.lg),
        trailing!,
      ],
    ],
  );
}

/// Use the available content width, not the whole screen beside the sidebar.
class DashboardPriorityLayout extends StatelessWidget {
  const DashboardPriorityLayout({super.key, required this.work, this.recent});
  final Widget work;
  final Widget? recent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final split =
          constraints.maxWidth >= 720 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.6;
      if (recent == null) return SizedBox(width: double.infinity, child: work);
      if (split) {
        return EqualHeightCards(gap: AppSpacing.lg, children: [work, recent!]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          work,
          const SizedBox(height: AppSpacing.md),
          recent!,
        ],
      );
    },
  );
}
