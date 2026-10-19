import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';

/// Account ownership is information, not a disabled location selector.
class LockedPlantAssignment extends StatelessWidget {
  const LockedPlantAssignment({
    super.key,
    required this.campus,
    required this.college,
    this.compact = false,
  });
  final String campus;
  final String college;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadii.medium,
      border: AppBorders.subtle,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: AppColors.green),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Managed By Your Account',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _entry(Icons.location_city_outlined, 'Campus', campus, inline: compact),
        const SizedBox(height: AppSpacing.sm),
        _entry(Icons.school_outlined, 'College', college, inline: compact),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Choose the physical planting location in Location.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );

  Widget _entry(
    IconData icon,
    String label,
    String value, {
    bool inline = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: inline
            ? Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}
