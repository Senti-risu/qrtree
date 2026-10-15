import 'package:flutter/material.dart';
import '../../../theme/app_layout.dart';

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
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: work),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: recent!),
            ],
          ),
        );
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
