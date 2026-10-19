import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

class PlantSummaryCard extends StatelessWidget {
  final String name;
  final String scientificName;
  final String plantedAt;
  final String managedBy;
  final String lastInspected;
  final Widget photo;
  final Widget status;
  final Widget? trailing;
  final VoidCallback onTap;

  const PlantSummaryCard({
    super.key,
    required this.name,
    required this.scientificName,
    required this.plantedAt,
    required this.managedBy,
    required this.lastInspected,
    required this.photo,
    required this.status,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.large,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  photo,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          scientificName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        status,
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _detail(
                context,
                Icons.location_on_outlined,
                'Planted At',
                plantedAt,
              ),
              _detail(context, Icons.school_outlined, 'Managed By', managedBy),
              _detail(
                context,
                Icons.fact_check_outlined,
                'Last Inspected',
                lastInspected,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
