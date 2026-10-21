import 'package:flutter/material.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_layout.dart';
import '../../../../utils/health_status_label.dart';
import '../../../../widgets/app_card.dart';

class RecentPlantsTable extends StatelessWidget {
  const RecentPlantsTable({
    super.key,
    required this.plants,
    required this.onViewAll,
    this.onViewPlant,
  });
  final List<Map<String, dynamic>> plants;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String, dynamic>>? onViewPlant;

  Map<String, dynamic> _relation(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) return _relation(value.first);
    return {};
  }

  String _value(dynamic value, String fallback) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();
  String _name(Map<String, dynamic> p) => _value(
    _relation(p['plant_classification'])['common_name'],
    'Unnamed plant',
  );
  String _tag(Map<String, dynamic> p) =>
      _value(_relation(p['qr_tag'])['qr_code_string'], 'Not Assigned');
  String _health(Map<String, dynamic> p) =>
      healthStatusLabel(_relation(p['health_status'])['status_name']);
  String _stage(Map<String, dynamic> p) =>
      _value(_relation(p['growth_status'])['growth_stage'], 'Not Recorded');
  String _inspection(Map<String, dynamic> p) {
    final date = DateTime.tryParse(p['last_inspected_on']?.toString() ?? '');
    if (date == null) return 'Not Inspected';
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

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Recent Plants. Open all plant records.',
    child: AppCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      boxShadow: const [],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final table =
              constraints.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.4;
          return InkWell(
            onTap: onViewAll,
            borderRadius: AppRadii.large,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Plants',
                              style: TextStyle(
                                fontSize: AppTypography.sectionTitle,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Keep an eye on your newest campus plants',
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${plants.length} plants',
                        style: const TextStyle(
                          fontSize: AppTypography.caption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (plants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No plants registered yet.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (table)
                  _table(context)
                else
                  for (final plant in plants) _mobileRow(plant),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Showing ${plants.length} recent ${plants.length == 1 ? "plant" : "plants"}',
                          style: const TextStyle(
                            fontSize: AppTypography.caption,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onViewAll,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _identity(Map<String, dynamic> plant) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: AppRadii.medium,
        ),
        child: const Icon(Icons.eco, color: AppColors.green, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _name(plant),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppTypography.body,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _value(plant['tree_planter'], 'Planter Not Recorded'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _badge(Map<String, dynamic> plant) {
    final health = _health(plant);
    final color = switch (health) {
      'Healthy' => AppColors.green,
      'Needs Attention' => AppColors.warning,
      'Dead' => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: AppRadii.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 5, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                health,
                style: TextStyle(fontSize: AppTypography.caption, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _view(Map<String, dynamic> plant) => OutlinedButton.icon(
    onPressed: () => onViewPlant == null ? onViewAll() : onViewPlant!(plant),
    icon: const Icon(Icons.open_in_new, size: 16),
    label: const Text(
      'View Plant',
      style: TextStyle(fontSize: AppTypography.caption),
    ),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );

  Widget _cell(Widget child, {bool heading = false, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: heading ? 16 : 22,
          ),
          child: child,
        ),
      );

  Widget _table(BuildContext context) => Table(
    columnWidths: const {
      0: FlexColumnWidth(2.0),
      1: FlexColumnWidth(1.8),
      2: FlexColumnWidth(1.3),
      3: FlexColumnWidth(1.3),
      4: FlexColumnWidth(1.4),
      5: FixedColumnWidth(170),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    border: const TableBorder(
      horizontalInside: BorderSide(color: AppColors.border),
    ),
    children: [
      TableRow(
        decoration: const BoxDecoration(color: AppColors.surfaceSubtle),
        children: [
          for (final label in [
            'PLANT',
            'TAG ID',
            'VARIETY / STAGE',
            'HEALTH',
            'LAST INSPECTION',
            'ACTION',
          ])
            _cell(
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                  color: AppColors.textSecondary,
                ),
              ),
              heading: true,
            ),
        ],
      ),
      for (final plant in plants)
        TableRow(
          children: [
            _cell(
              _identity(plant),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
            _cell(
              SelectableText(
                _tag(plant),
                style: const TextStyle(
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
            _cell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _value(plant['variety'], 'Not Specified'),
                    style: const TextStyle(fontSize: AppTypography.body),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stage(plant),
                    style: const TextStyle(
                      fontSize: AppTypography.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
            _cell(
              _badge(plant),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
            _cell(
              Text(
                _inspection(plant),
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
            _cell(
              _view(plant),
              onTap: onViewPlant == null ? null : () => onViewPlant!(plant),
            ),
          ],
        ),
    ],
  );

  Widget _mobileRow(Map<String, dynamic> plant) => Semantics(
    button: true,
    label: 'Open ${_name(plant)} plant record',
    child: InkWell(
      onTap: () => onViewPlant == null ? onViewAll() : onViewPlant!(plant),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _identity(plant),
              const SizedBox(height: 12),
              SelectableText(
                _tag(plant),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: AppTypography.caption,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  Text(_value(plant['variety'], 'Not Specified')),
                  Text(
                    _stage(plant),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _badge(plant),
              const SizedBox(height: 12),
              Text(
                'Last Inspection: ${_inspection(plant)}',
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: _view(plant)),
            ],
          ),
        ),
      ),
    ),
  );
}
