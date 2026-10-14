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
  });

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 142),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: AppRadii.medium,
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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
                    maxLines: largeText ? 2 : 1,
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
                  maxLines: largeText ? 2 : 1,
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
    );
  }
}
