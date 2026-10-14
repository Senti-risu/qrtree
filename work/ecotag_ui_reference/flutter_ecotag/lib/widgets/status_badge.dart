import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final HealthStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      HealthStatus.healthy => (AppColors.healthy, AppColors.healthyContainer, 'Healthy'),
      HealthStatus.dying => (AppColors.warning, AppColors.warningContainer, 'Dying'),
      HealthStatus.dead => (AppColors.danger, AppColors.dangerContainer, 'Dead'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppSpacing.badgeRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class InspectionStatusBadge extends StatelessWidget {
  final String status;

  const InspectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status.toLowerCase() == 'completed';
    final color = isCompleted ? AppColors.info : AppColors.warning;
    final bg = isCompleted ? AppColors.infoContainer : AppColors.warningContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppSpacing.badgeRadius),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
