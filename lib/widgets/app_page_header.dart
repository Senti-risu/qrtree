import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      mergeWithParent: true,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions =
              trailing != null &&
              (!AppBreakpoints.isDesktop(constraints.maxWidth) ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4);
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );

          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xl),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .5,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
