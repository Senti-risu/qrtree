import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

class PlantSummaryCard extends StatelessWidget {
  final String name;
  final String plantType;
  final String scientificName;
  final String plantedAt;
  final String role;
  final String? campus;
  final String? college;
  final Widget photo;
  final Widget status;
  final Widget? trailing;
  final VoidCallback onTap;

  const PlantSummaryCard({
    super.key,
    required this.name,
    required this.plantType,
    required this.scientificName,
    required this.plantedAt,
    required this.role,
    this.campus,
    this.college,
    required this.photo,
    required this.status,
    required this.onTap,
    this.trailing,
  });

  String? get _managementLabel => switch (role) {
    'campus_admin' => 'Managed By College',
    'university_admin' => 'Managed By Campus',
    'college_admin' || 'inspection_team' => null,
    _ => 'Managed By',
  };

  String? get _managementValue => switch (role) {
    'campus_admin' => college,
    'university_admin' => campus,
    'college_admin' || 'inspection_team' => null,
    _ => [
      college,
      campus,
    ].whereType<String>().where((name) => name.isNotEmpty).join(' · '),
  };

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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _badge(
                    context,
                    plantType,
                    AppColors.primaryContainer,
                    AppColors.darkGreen,
                  ),
                  status,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _detail(
                context,
                Icons.location_on_outlined,
                'Planted At',
                plantedAt,
              ),
              if (_managementLabel != null &&
                  _managementValue != null &&
                  _managementValue!.isNotEmpty)
                _detail(
                  context,
                  Icons.school_outlined,
                  _managementLabel!,
                  _managementValue!,
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _badge(
    BuildContext context,
    String label,
    Color background,
    Color foreground,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadii.fullyRounded,
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
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
