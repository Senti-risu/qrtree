import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/user_facing_error.dart';
import 'app_card.dart';
import 'full_width_data_table.dart';

class MonitoringOutcomesCard extends StatefulWidget {
  const MonitoringOutcomesCard({super.key});
  @override
  State<MonitoringOutcomesCard> createState() => _MonitoringOutcomesCardState();
}

class _MonitoringOutcomesCardState extends State<MonitoringOutcomesCard> {
  late Future<Map<String, dynamic>> _data;
  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await Supabase.instance.client
            .rpc(
              'monitoring_outcomes',
              params: {'p_session_token': AppSession.requiredToken},
            )
            .timeout(const Duration(seconds: 25))
        as Map,
  );
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  String _rate(num part, num total) =>
      total == 0 ? 'N/A' : '${(100 * part / total).toStringAsFixed(1)}%';
  Widget _table(List<String> headings, List<List<String>> rows) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FullWidthDataTable(
          minimumWidth: 520,
          columns: headings.map((h) => DataColumn(label: Text(h))).toList(),
          rows: rows
              .map(
                (r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()),
              )
              .toList(),
        ),
      ),
    ),
  );
  Widget _heading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: AppTypography.body,
          fontWeight: FontWeight.w800,
          color: AppColors.darkGreen,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        description,
        style: const TextStyle(
          fontSize: AppTypography.caption,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Monitoring Outcomes',
          style: TextStyle(
            fontSize: AppTypography.sectionTitle,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Covers your full assigned scope, including archived records in survival and health history. These tables are independent of the plant filters above.',
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.textSecondary,
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(
                    userFacingError(
                      snapshot.error!,
                      fallback: 'Outcome metrics unavailable.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _data = _load()),
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'As of ${data['generated_on']} (Philippine time)',
                  style: const TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _heading(
                  'Survival By Planting Month',
                  'Batch = planting month. Survival = plants with a recorded non-Dead status ÷ all registered plants in the batch. Missing or unrecognized statuses are counted as Needs Attention and are not treated as confirmed survivors.',
                ),
                _table(
                  [
                    'Planting Month',
                    'Registered',
                    'Alive',
                    'Needs Attention',
                    'Survival',
                  ],
                  [
                    for (final b in (data['batches'] as List).where(
                      (b) => b['batch'] != null,
                    ))
                      [
                        '${b['batch']}',
                        '${b['total']}',
                        '${b['alive']}',
                        '${b['needs_attention']}',
                        _rate(b['alive'] as num, b['total'] as num),
                      ],
                  ],
                ),
                const SizedBox(height: 24),
                _heading(
                  'Inspection coverage by college — last 30 days',
                  'Coverage = active non-Dead plants inspected in the last 30 calendar days ÷ active non-Dead plants. This measures coverage, not on-time schedule compliance.',
                ),
                _table(
                  ['College', 'Eligible Plants', 'Inspected', 'Coverage'],
                  [
                    for (final c in data['colleges'] as List)
                      [
                        '${c['college_name'] ?? 'Unassigned'}',
                        '${c['total']}',
                        '${c['completed']}',
                        _rate(c['completed'] as num, c['total'] as num),
                      ],
                  ],
                ),
                const SizedBox(height: 24),
                _heading(
                  'Health Observations Over Time',
                  'Counts inspection observations by observation month and health status. A plant inspected multiple times contributes multiple observations.',
                ),
                _table(
                  ['Month', 'Health', 'Observations'],
                  [
                    for (final h in data['health'] as List)
                      [
                        '${h['month']}',
                        '${h['health'] ?? 'Needs Attention'}',
                        '${h['observations']}',
                      ],
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
