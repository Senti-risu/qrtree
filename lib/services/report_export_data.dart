import 'dart:convert';
import 'dart:typed_data';

import '../models/inspection_schedule.dart';
import '../utils/health_status_label.dart';

enum ReportKind {
  inventory('Plant Inventory'),
  schedule('Inspection Schedule'),
  history('Inspection History'),
  health('Plant Health Summary'),
  outcomes('Monitoring Outcomes'),
  action('Plants Needing Action');

  const ReportKind(this.label);
  final String label;
}

class ReportSection {
  const ReportSection(this.title, this.headers, this.rows, {this.note});
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String? note;
}

class ExportReport {
  const ExportReport({
    required this.kind,
    required this.metadata,
    required this.sections,
  });
  final ReportKind kind;
  final Map<String, String> metadata;
  final List<ReportSection> sections;

  /// UTF-8 BOM for Excel; quotes/newlines round-trip and formulas stay text.
  Uint8List csvBytes() {
    final rows = <List<String>>[
      ['EcoTag', kind.label],
      for (final entry in metadata.entries) [entry.key, entry.value],
      for (final section in sections) ...[
        [],
        [section.title],
        if (section.note != null) ['Note', section.note!],
        section.headers,
        ...section.rows,
        if (section.rows.isEmpty) ['No matching records.'],
      ],
    ];
    final width = rows.fold<int>(2, (a, b) => a > b.length ? a : b.length);
    String cell(String value) {
      final trimmed = value.trimLeft();
      final safe =
          RegExp(r'^[=+@\-\t\r\n]').hasMatch(trimmed) ||
              value.startsWith('\t') ||
              value.startsWith('\r') ||
              value.startsWith('\n')
          ? "'$value"
          : value;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final csv = rows
        .map(
          (row) => List.generate(
            width,
            (i) => cell(i < row.length ? row[i] : ''),
          ).join(','),
        )
        .join('\r\n');
    return Uint8List.fromList(utf8.encode('\uFEFF$csv\r\n'));
  }
}

class ReportExportData {
  static Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  static String related(
    Map<String, dynamic> row,
    String relation,
    String field,
  ) => text(map(row[relation])[field]);
  static String text(dynamic value) =>
      value == null || value.toString().trim().isEmpty
      ? 'Not recorded'
      : value.toString();
  static String date(dynamic value) {
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Not recorded'
        : '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  static DateTime manilaNow([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  static String observationDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Not recorded'
        : date(parsed.toUtc().add(const Duration(hours: 8)));
  }

  static String health(Map<String, dynamic> p) {
    return healthStatusLabel(map(p['health_status'])['status_name']);
  }

  static String tag(Map<String, dynamic> p) =>
      related(p, 'qr_tag', 'qr_code_string');
  static String name(Map<String, dynamic> p) =>
      related(p, 'plant_classification', 'common_name');
  static int comparePlantIds(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (a['plant_id'] as int).compareTo(b['plant_id'] as int);
  static String location(Map<String, dynamic> p) => [
    related(p, 'campus', 'campus_name'),
    related(p, 'town', 'town_name'),
    related(p, 'barangay', 'barangay_name'),
  ].where((s) => s != 'Not recorded').join(' / ');
  static DateTime? due(Map<String, dynamic> p) {
    if (health(p) == 'Dead' || p['archived_at'] != null) return null;
    DateTime? day(dynamic value) {
      final d = DateTime.tryParse(value?.toString() ?? '');
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    return day(p['next_inspection_due_on']) ??
        (day(p['last_inspected_on']) ??
                day(p['date_planted']) ??
                day(p['created_at']))
            ?.add(Duration(days: InspectionSchedule.intervalDays(p)));
  }

  static String scheduleStatus(Map<String, dynamic> p, DateTime now) {
    if (p['archived_at'] != null || health(p) == 'Dead') {
      return 'Not Applicable';
    }
    final d = due(p);
    if (d == null) return 'Unscheduled';
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today)
        ? 'Overdue'
        : d == today
        ? 'Due Today'
        : 'Upcoming';
  }

  static ExportReport build({
    required ReportKind kind,
    required List<Map<String, dynamic>> plants,
    required String scope,
    required String preparedBy,
    required String filters,
    required DateTime generated,
    List<Map<String, dynamic>> history = const [],
    Map<String, dynamic>? outcomes,
    String inspectionPeriod = 'All inspection dates',
  }) {
    final sections = <ReportSection>[];
    final metadata = {
      'Scope': scope,
      'Prepared by': preparedBy,
      'Generated (Asia/Manila)':
          '${date(generated)} ${generated.hour.toString().padLeft(2, '0')}:${generated.minute.toString().padLeft(2, '0')}',
      'Plant selection': kind == ReportKind.outcomes
          ? 'Full assigned scope; page filters do not apply.'
          : filters,
      'Record coverage': kind == ReportKind.outcomes
          ? 'Survival and health observations include archived plants; coverage excludes archived/dead plants.'
          : '${plants.length} matching active plant records; archived plants excluded.',
      if (kind == ReportKind.history)
        'Inspection period (Asia/Manila)': inspectionPeriod,
    };
    switch (kind) {
      case ReportKind.inventory:
        sections.add(
          ReportSection(
            'Inventory Summary',
            ['Metric', 'Plants'],
            [
              ['Total Plants', '${plants.length}'],
              for (final status in ['Healthy', 'Needs Attention', 'Dead'])
                [status, '${plants.where((p) => health(p) == status).length}'],
              [
                'Inspected At Least Once',
                '${plants.where((p) => p['last_inspected_on'] != null).length}',
              ],
              [
                'No Recorded Inspection Date',
                '${plants.where((p) => p['last_inspected_on'] == null).length}',
              ],
            ],
          ),
        );
        sections.add(
          ReportSection(
            'Registered Plants',
            [
              'QR ID',
              'Plant',
              'Type',
              'Location',
              'College',
              'Date Planted',
              'Last Inspection',
              'Stage',
              'Health',
            ],
            [
              for (final p in plants)
                [
                  tag(p),
                  name(p),
                  related(p, 'plant_classification', 'plant_type'),
                  location(p),
                  related(p, 'college', 'college_name'),
                  date(p['date_planted']),
                  date(p['last_inspected_on']),
                  related(p, 'growth_status', 'growth_stage'),
                  health(p),
                ],
            ],
          ),
        );
        sections.add(
          ReportSection(
            'Classification Details',
            [
              'QR ID',
              'Plant',
              'Scientific Name',
              'Variety',
              'Tree Planter',
              'Registered (Asia/Manila)',
            ],
            [
              for (final p in plants)
                [
                  tag(p),
                  name(p),
                  related(p, 'plant_classification', 'scientific_name'),
                  text(p['variety']),
                  text(p['tree_planter']),
                  observationDate(p['created_at']),
                ],
            ],
          ),
        );
      case ReportKind.schedule:
        final rows =
            plants
                .where((p) => scheduleStatus(p, generated) != 'Not Applicable')
                .toList()
              ..sort((a, b) {
                final order = (due(a) ?? DateTime(9999)).compareTo(
                  due(b) ?? DateTime(9999),
                );
                return order == 0 ? comparePlantIds(a, b) : order;
              });
        sections.add(
          ReportSection(
            'Inspection Schedule',
            [
              'QR ID',
              'Plant',
              'Location',
              'Health',
              'Last Inspection',
              'Next Due',
              'Interval (Days)',
              'Status',
            ],
            [
              for (final p in rows)
                [
                  tag(p),
                  name(p),
                  location(p),
                  health(p),
                  date(p['last_inspected_on']),
                  date(due(p)),
                  '${InspectionSchedule.intervalDays(p)}',
                  scheduleStatus(p, generated),
                ],
            ],
            note:
                'As of ${date(generated)} (Asia/Manila). Dead and archived plants are excluded. Due dates use the existing schedule or its configured interval fallback.',
          ),
        );
      case ReportKind.history:
        final byId = {for (final p in plants) p['plant_id']: p};
        final rows =
            history.where((h) => byId.containsKey(h['plant_id'])).toList()
              ..sort((a, b) {
                DateTime observed(Map<String, dynamic> row) =>
                    DateTime.tryParse(
                      '${row['observed_at'] ?? row['inspected_at'] ?? ''}',
                    )?.toUtc() ??
                    DateTime.utc(1900);
                final order = observed(b).compareTo(observed(a));
                if (order != 0) return order;
                final firstId = int.tryParse('${a['inspection_id']}');
                final secondId = int.tryParse('${b['inspection_id']}');
                return firstId != null && secondId != null
                    ? secondId.compareTo(firstId)
                    : '${b['inspection_id']}'.compareTo(
                        '${a['inspection_id']}',
                      );
              });
        sections.add(
          ReportSection(
            'Inspection History',
            [
              'Inspection ID',
              'Observed On',
              'QR ID',
              'Plant',
              'Inspector',
              'Observed Health',
              'Observed Stage',
              'Findings / Remarks',
              'Current Next Due',
            ],
            [
              for (final h in rows)
                [
                  text(h['inspection_id']),
                  observationDate(h['observed_at'] ?? h['inspected_at']),
                  tag(byId[h['plant_id']]!),
                  name(byId[h['plant_id']]!),
                  text(h['inspector']),
                  healthStatusLabel(h['health']),
                  text(h['growth_stage']),
                  text(h['observation']),
                  date(due(byId[h['plant_id']]!)),
                ],
            ],
            note:
                'Health and stage are recorded observations. Current next due is the present plant schedule, not a historical schedule snapshot.',
          ),
        );
      case ReportKind.health:
        sections.add(
          ReportSection(
            'Health Distribution',
            ['Health', 'Plants', 'Percentage'],
            [
              for (final status in ['Healthy', 'Needs Attention', 'Dead'])
                [
                  status,
                  '${plants.where((p) => health(p) == status).length}',
                  plants.isEmpty
                      ? 'N/A'
                      : '${(100 * plants.where((p) => health(p) == status).length / plants.length).toStringAsFixed(1)}%',
                ],
            ],
          ),
        );
        sections.add(
          ReportSection(
            'Growth Stages',
            ['Stage', 'Plants'],
            [
              for (final stage
                  in (plants
                      .map((p) => related(p, 'growth_status', 'growth_stage'))
                      .toSet()
                      .toList()
                    ..sort()))
                [
                  stage,
                  '${plants.where((p) => related(p, 'growth_status', 'growth_stage') == stage).length}',
                ],
            ],
          ),
        );
      case ReportKind.action:
        final rows = plants
            .where(
              (p) =>
                  health(p) == 'Needs Attention' ||
                  [
                    'Overdue',
                    'Due Today',
                    'Unscheduled',
                  ].contains(scheduleStatus(p, generated)),
            )
            .toList();
        sections.add(
          ReportSection(
            'Plants Needing Follow-up',
            [
              'QR ID',
              'Plant',
              'Location',
              'Health',
              'Last Inspection',
              'Next Due',
              'Issue',
              'Suggested Follow-up',
            ],
            [
              for (final p in rows)
                [
                  tag(p),
                  name(p),
                  location(p),
                  health(p),
                  date(p['last_inspected_on']),
                  date(due(p)),
                  [
                    if (health(p) == 'Needs Attention') 'Needs Attention',
                    if ([
                      'Overdue',
                      'Due Today',
                      'Unscheduled',
                    ].contains(scheduleStatus(p, generated)))
                      scheduleStatus(p, generated),
                  ].join('; '),
                  scheduleStatus(p, generated) == 'Unscheduled'
                      ? 'Set an inspection date.'
                      : health(p) == 'Dead'
                      ? 'Review the dead plant record; no inspection is scheduled.'
                      : health(p) == 'Needs Attention'
                      ? 'Arrange an inspection and assess plant condition.'
                      : 'Complete the scheduled inspection.',
                ],
            ],
            note:
                'Suggested follow-ups are workflow prompts, not treatment advice.',
          ),
        );
      case ReportKind.outcomes:
        if (outcomes == null) {
          throw StateError('Monitoring outcomes were not loaded.');
        }
        metadata['Outcome as-of date (Asia/Manila)'] = text(
          outcomes['generated_on'],
        );
        String rate(dynamic part, dynamic total) =>
            total is num && part is num && total > 0
            ? '${(100 * part / total).toStringAsFixed(1)}%'
            : 'N/A';
        sections.add(
          ReportSection(
            'Survival by Planting Month',
            [
              'Planting Month',
              'Registered',
              'Alive',
              'Needs Attention',
              'Survival',
            ],
            [
              for (final b in outcomes['batches'] as List)
                [
                  text(b['batch']),
                  text(b['total']),
                  text(b['alive']),
                  text(b['needs_attention']),
                  rate(b['alive'], b['total']),
                ],
            ],
            note:
                'Known non-dead plants / all registered plants in the planting batch. Missing or unrecognized health statuses are counted as Needs Attention and are not treated as confirmed survivors.',
          ),
        );
        sections.add(
          ReportSection(
            'Inspection Coverage - Last 30 Calendar Days',
            ['College', 'Eligible Plants', 'Inspected', 'Coverage'],
            [
              for (final c in outcomes['colleges'] as List)
                [
                  text(c['college_name']),
                  text(c['total']),
                  text(c['completed']),
                  rate(c['completed'], c['total']),
                ],
            ],
            note:
                'Active non-dead plants inspected in the last 30 days / active non-dead plants. Coverage is not on-time schedule compliance.',
          ),
        );
        sections.add(
          ReportSection(
            'Health Observations over Time',
            ['Observation Month', 'Health', 'Observations'],
            [
              for (final h in outcomes['health'] as List)
                [
                  text(h['month']),
                  healthStatusLabel(h['health']),
                  text(h['observations']),
                ],
            ],
            note:
                'Counts observations, not unique plants. A plant inspected multiple times contributes multiple observations.',
          ),
        );
    }
    return ExportReport(kind: kind, metadata: metadata, sections: sections);
  }
}
