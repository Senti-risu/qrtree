import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../widgets/app_card.dart';

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String? percentage;
  final double? progress;
  final VoidCallback? onTap;
  final bool compact;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.percentage,
    this.progress,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 106 : 120),
          child: AppCard(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 30 : 42,
                      height: compact ? 30 : 42,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: AppRadii.medium,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: compact ? 19 : 23,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: compact || largeText ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (percentage != null && percentage!.isNotEmpty)
                      Text(
                        percentage!,
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (subtext.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtext,
                      maxLines: compact || largeText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1),
                      minHeight: 3,
                      color: iconColor,
                      backgroundColor: AppColors.border,
                      borderRadius: AppRadii.small,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
