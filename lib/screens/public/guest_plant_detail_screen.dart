import 'package:flutter/material.dart';

import '../../services/guest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../widgets/app_card.dart';
import '../../widgets/plant_details_presentation.dart';
import '../../widgets/plant_ecotag_header.dart';

/// Curated public plant profile shown to guests after a successful scan.
///
/// This screen intentionally has no inspection history, scheduling, editing,
/// archive, registration, printing, or account information.
class GuestPlantDetailScreen extends StatelessWidget {
  const GuestPlantDetailScreen({super.key, required this.plant});

  final GuestPlantProfile plant;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Plant Details'),
      leading: PlantDetailsPresentation.floatsFor(MediaQuery.sizeOf(context))
          ? IconButton(
              tooltip: 'Close plant details',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
            )
          : const BackButton(),
      backgroundColor: AppColors.background,
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = AppBreakpoints.isPhone(constraints.maxWidth);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              12,
              compact ? 16 : 28,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlantEcoTagHeader(code: plant.qrCode),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: AppColors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Guest view · This plant profile is read-only.',
                                style: TextStyle(
                                  color: AppColors.darkGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: SizedBox(
                                height: compact ? 200 : 240,
                                child: _PlantPhoto(url: plant.photoUrl),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(compact ? 18 : 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plant.commonName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppColors.darkGreen,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plant.scientificName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusChip(
                                        icon: Icons.health_and_safety_outlined,
                                        label: _value(
                                          plant.healthStatus,
                                          'Health not provided',
                                        ),
                                      ),
                                      _StatusChip(
                                        icon: Icons.spa_outlined,
                                        label: _value(
                                          plant.growthStage,
                                          'Stage not provided',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(
                        title: 'Plant information',
                        icon: Icons.eco_outlined,
                        rows: {
                          'Plant type': plant.plantType,
                          'Variety': _value(plant.variety),
                          'Date planted': _formatDate(plant.datePlanted),
                          'Tree planter': _value(plant.treePlanter),
                        },
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(
                        title: 'Managed by',
                        icon: Icons.location_on_outlined,
                        rows: {
                          'Managing campus': _value(plant.campusName),
                          'Managing college': _value(plant.collegeName),
                        },
                      ),
                      const SizedBox(height: 14),
                      _DetailSection(
                        title: 'Planting location',
                        icon: Icons.location_on_outlined,
                        rows: {
                          'Campus / outside': plant.plantingLocationLabel,
                          'Town': _value(plant.townName),
                          'Barangay': _value(plant.barangayName),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  static String _value(String? value, [String fallback = 'Not provided']) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return _value(value);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

class _PlantPhoto extends StatelessWidget {
  const _PlantPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return const _PlantPhotoPlaceholder();
    return Image.network(
      normalized,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _PlantPhotoPlaceholder(),
    );
  }
}

class _PlantPhotoPlaceholder extends StatelessWidget {
  const _PlantPhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.primaryContainer,
    child: Center(
      child: Icon(
        Icons.local_florist_rounded,
        size: 86,
        color: AppColors.green,
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.green),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rows.entries.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
