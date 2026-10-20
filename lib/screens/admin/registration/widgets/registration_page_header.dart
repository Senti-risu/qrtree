import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_layout.dart';
import '../../../../widgets/app_card.dart';

class RegistrationPageHeader extends StatelessWidget {
  const RegistrationPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register Plant',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add a new plant to the EcoTag Campus Plant Profiling System.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadii.medium,
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
