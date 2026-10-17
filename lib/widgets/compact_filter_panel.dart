import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Two compact rows on wide screens, wrapping rather than clipping when narrow.
class CompactFilterPanel extends StatelessWidget {
  final Widget search;
  final List<Widget> controls;
  final List<Widget> choices;
  final String resultSummary;

  const CompactFilterPanel({
    super.key,
    required this.search,
    required this.controls,
    required this.choices,
    required this.resultSummary,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inline =
          constraints.maxWidth >= 800 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.4;
      final actions = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: controls,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inline)
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            )
          else ...[
            search,
            if (controls.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              actions,
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...choices,
              Text(
                resultSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      );
    },
  );
}
