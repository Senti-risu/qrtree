import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_session.dart';
import '../utils/user_facing_error.dart';

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
  Widget _table(List<String> headings, List<List<String>> rows) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: headings.map((h) => DataColumn(label: Text(h))).toList(),
          rows: rows
              .map(
                (r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()),
              )
              .toList(),
        ),
      );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Monitoring outcomes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Covers your full assigned scope, including archived records in survival and health history. These tables are independent of the plant filters above.',
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
                  Text('As of ${data['generated_on']} (Philippine time)'),
                  const SizedBox(height: 12),
                  const Text(
                    'Survival by planting month',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Batch = planting month. Survival = plants with a known non-Dead status ÷ all registered plants in the batch. Unknown statuses remain in the denominator.',
                  ),
                  _table(
                    [
                      'Planting month',
                      'Registered',
                      'Alive',
                      'Unknown',
                      'Survival',
                    ],
                    [
                      for (final b in data['batches'] as List)
                        [
                          '${b['batch'] ?? 'Unknown date'}',
                          '${b['total']}',
                          '${b['alive']}',
                          '${b['unknown']}',
                          _rate(b['alive'] as num, b['total'] as num),
                        ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Inspection coverage by college — last 30 days',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Coverage = active non-Dead plants inspected in the last 30 calendar days ÷ active non-Dead plants. This measures coverage, not on-time schedule compliance.',
                  ),
                  _table(
                    ['College', 'Eligible plants', 'Inspected', 'Coverage'],
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
                  const SizedBox(height: 16),
                  const Text(
                    'Health observations over time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Counts inspection observations by observation month and health status. A plant inspected multiple times contributes multiple observations.',
                  ),
                  _table(
                    ['Month', 'Health', 'Observations'],
                    [
                      for (final h in data['health'] as List)
                        [
                          '${h['month']}',
                          '${h['health'] ?? 'Unknown'}',
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
    ),
  );
}
