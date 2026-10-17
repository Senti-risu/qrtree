import 'package:flutter/material.dart';
import '../../../theme/app_typography.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../widgets/app_card.dart';

class CampusOverviewCard extends StatelessWidget {
  final Map<String, int> counts;

  const CampusOverviewCard({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maximum = entries.fold<int>(
      0,
      (value, item) => item.value > value ? item.value : value,
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSU Campuses',
            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Registered plants by campus',
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No campus plant data available.')),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: maximum == 0 ? 0 : entry.value / maximum,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.green,
                        backgroundColor: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entry.value}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.w700,
                        ),
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
}
