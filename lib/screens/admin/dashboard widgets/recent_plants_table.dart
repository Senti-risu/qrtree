import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../widgets/app_card.dart';

class RecentPlantsTable extends StatelessWidget {
  final List<Map<String, dynamic>> plants;
  final VoidCallback onViewAll;

  const RecentPlantsTable({
    super.key,
    required this.plants,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isPhone(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(compact),
            const SizedBox(height: AppSpacing.xl),
            if (plants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No plants registered yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else if (compact)
              ...plants.map(_mobilePlantCard)
            else
              _desktopTable(),
          ],
        );
      },
    );
  }

  Widget _header(bool compact) {
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Plants',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          'Recently registered or updated plants',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
    final action = OutlinedButton(
      onPressed: onViewAll,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.green),
        minimumSize: const Size(88, AppLayout.minimumTapTarget),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.fullyRounded,
        ),
      ),
      child: const Text(
        'View All',
        style: TextStyle(color: AppColors.green, fontSize: 13),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (compact) const Expanded(child: title) else title,
        const SizedBox(width: 10),
        action,
      ],
    );
  }

  Widget _desktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 32,
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceSubtle),
        columns: const [
          DataColumn(
            label: Text(
              'PLANT',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'TYPE',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'VARIETY',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'CAMPUS',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'GROWTH STAGE',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'HEALTH',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'DATE PLANTED',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        rows: plants.map((plant) {
          final summary = _summary(plant);
          return _buildTableRow(
            summary.name,
            summary.type,
            summary.variety,
            summary.campus,
            summary.stage,
            summary.health,
            summary.date,
          );
        }).toList(),
      ),
    );
  }

  Widget _mobilePlantCard(Map<String, dynamic> plant) {
    final summary = _summary(plant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadii.medium,
                  ),
                  child: const Icon(
                    Icons.local_florist_rounded,
                    size: 22,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      Text(
                        summary.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _healthChip(summary.health),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 11),
            LayoutBuilder(
              builder: (context, constraints) {
                final detailWidth = constraints.maxWidth >= 280
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 11,
                  children: [
                    _detail('Variety', summary.variety, detailWidth),
                    _detail('Campus', summary.campus, detailWidth),
                    _detail('Growth stage', summary.stage, detailWidth),
                    _detail('Date planted', summary.date, detailWidth),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _healthChip(String health) {
    final color = _healthColor(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: AppRadii.fullyRounded,
      ),
      child: Text(
        health,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  DataRow _buildTableRow(
    String plant,
    String type,
    String variety,
    String campus,
    String stage,
    String health,
    String date,
  ) {
    final healthColor = _healthColor(health);
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              const Icon(
                Icons.local_florist,
                size: 16,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              Text(plant, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        DataCell(Text(type)),
        DataCell(Text(variety)),
        DataCell(Text(campus)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentPurpleContainer,
              borderRadius: AppRadii.small,
            ),
            child: Text(
              stage,
              style: TextStyle(
                color: AppColors.accentPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: healthColor,
              borderRadius: AppRadii.small,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  health,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Text(date, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  _PlantSummary _summary(Map<String, dynamic> plant) {
    final classification = _relation(plant['plant_classification']);
    final campus = _relation(plant['campus']);
    final growth = _relation(plant['growth_status']);
    final health = _relation(plant['health_status']);
    final healthName = health['status_name']?.toString().toLowerCase() ?? '';
    final healthLabel = switch (healthName) {
      'alive' => 'Healthy',
      'dying' => 'At Risk',
      'dead' => 'Dead',
      _ => 'Unknown',
    };

    return _PlantSummary(
      name: classification['common_name']?.toString() ?? 'Unnamed plant',
      type: classification['plant_type']?.toString() ?? 'Not specified',
      variety: plant['variety']?.toString() ?? 'Not specified',
      campus: campus['campus_name']?.toString() ?? 'Not assigned',
      stage: growth['growth_stage']?.toString() ?? 'Not recorded',
      health: healthLabel,
      date: _formatDate(plant['date_planted']),
    );
  }

  Map<String, dynamic> _relation(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  Color _healthColor(String health) => switch (health) {
    'Healthy' => AppColors.green,
    'At Risk' => AppColors.warningAccent,
    'Dead' => AppColors.danger,
    _ => AppColors.textSecondary,
  };

  String _formatDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Not recorded';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _PlantSummary {
  const _PlantSummary({
    required this.name,
    required this.type,
    required this.variety,
    required this.campus,
    required this.stage,
    required this.health,
    required this.date,
  });

  final String name;
  final String type;
  final String variety;
  final String campus;
  final String stage;
  final String health;
  final String date;
}
