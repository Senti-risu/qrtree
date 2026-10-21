import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/report_export_data.dart';
import 'package:flutter_application_1/services/report_export_service.dart';

Map<String, dynamic> plant(
  int id, {
  String health = 'Healthy',
  String? due = '2026-10-19',
}) => {
  'plant_id': id,
  'variety': 'Indian',
  'tree_planter': 'Dela Cruz, Ana',
  'created_at': '2026-10-01',
  'date_planted': '2026-09-28',
  'last_inspected_on': '2026-10-12',
  'next_inspection_due_on': due,
  'inspection_interval_days': 7,
  'plant_classification': {
    'common_name': 'Mango $id',
    'scientific_name': 'Mangifera indica',
    'plant_type': 'Tree',
  },
  'health_status': {'status_name': health},
  'growth_status': {'growth_stage': 'Seedling'},
  'qr_tag': {'qr_code_string': 'ECOTAG-$id'},
  'campus': {'campus_name': 'CSU Lasam'},
  'college': {'college_name': 'College of Information and Computing Sciences'},
  'town': {'town_name': 'Lasam'},
  'barangay': {'barangay_name': 'Centro'},
};

ExportReport report(
  ReportKind kind, {
  List<Map<String, dynamic>>? plants,
  List<Map<String, dynamic>> history = const [],
  Map<String, dynamic>? outcomes,
}) => ReportExportData.build(
  kind: kind,
  plants: plants ?? [plant(1)],
  history: history,
  outcomes: outcomes,
  scope: 'Assigned College',
  preparedBy: 'College Admin',
  filters: 'Health: All; Registration dates: All',
  generated: DateTime(2026, 10, 19, 10, 30),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('inventory preserves planting, classification, location and totals', () {
    final data = report(ReportKind.inventory);
    expect(data.sections.first.rows.first, ['Total Plants', '1']);
    expect(
      data.sections[1].rows.single,
      contains('CSU Lasam / Lasam / Centro'),
    );
    expect(data.sections[1].rows.single, contains('2026-09-28'));
    expect(data.sections.last.rows.single, contains('Mangifera indica'));
    expect(data.sections.last.rows.single, contains('Dela Cruz, Ana'));
  });
  test('schedule respects calendar day, interval and dead plant exclusion', () {
    final data = report(
      ReportKind.schedule,
      plants: [
        plant(1, due: '2026-10-18'),
        plant(2),
        plant(3, due: '2026-10-20'),
        plant(4, health: 'Dead'),
      ],
    );
    expect(data.sections.single.rows.map((r) => r.last), [
      'Overdue',
      'Due Today',
      'Upcoming',
    ]);
    expect(ReportExportData.due(plant(1, due: null)), DateTime(2026, 10, 19));
    expect(ReportExportData.due(plant(4, health: 'Dead')), isNull);
  });
  test('unscheduled plants are explicit, not incorrectly called overdue', () {
    final p = plant(1, due: null)
      ..remove('created_at')
      ..remove('date_planted')
      ..remove('last_inspected_on');
    expect(
      ReportExportData.scheduleStatus(p, DateTime(2026, 10, 19)),
      'Unscheduled',
    );
    expect(
      report(ReportKind.action, plants: [p]).sections.single.rows.single.last,
      'Set an inspection date.',
    );
  });
  test(
    'history uses observed date in Manila, recorded health and selected IDs only',
    () {
      final data = report(
        ReportKind.history,
        history: [
          {
            'inspection_id': 1,
            'plant_id': 1,
            'observed_at': '2026-10-18T18:00:00Z',
            'health': 'Dying',
            'growth_stage': 'Mature',
            'inspector': 'Inspector',
            'observation': 'Leaves yellow',
          },
          {'inspection_id': 2, 'plant_id': 99, 'health': 'Dead'},
        ],
      );
      expect(data.sections.single.rows.length, 1);
      expect(data.sections.single.rows.single[1], '2026-10-19');
      expect(data.sections.single.rows.single[5], 'Needs Attention');
      expect(data.sections.single.rows.single[6], 'Mature');
      expect(
        data.sections.single.note,
        contains('not a historical schedule snapshot'),
      );
    },
  );
  test(
    'CSV quotes commas, newlines, quotes and neutralizes formula injection',
    () {
      final data = ExportReport(
        kind: ReportKind.inventory,
        metadata: const {},
        sections: const [
          ReportSection(
            'Test',
            ['Text'],
            [
              ['Dela Cruz, Ana'],
              ['Line 1\nLine "2"'],
              ['=HYPERLINK("bad")'],
              ['  +SUM(1,2)'],
              ['@command'],
              ['-command'],
              ['\t=bad'],
            ],
          ),
        ],
      );
      final csv = utf8.decode(data.csvBytes());
      expect(data.csvBytes().take(3), [0xEF, 0xBB, 0xBF]);
      expect(csv, contains('"Dela Cruz, Ana"'));
      expect(csv, contains('"Line 1\nLine ""2"""'));
      expect(csv, contains('"\'=HYPERLINK(""bad"")"'));
      expect(csv, contains('"\'  +SUM(1,2)"'));
      expect(csv, contains('"\'@command"'));
      expect(csv, contains('"\'-command"'));
      expect(csv, contains('"\'\t=bad"'));
    },
  );
  test(
    'health percentages flag unrecognized status and handle zero totals',
    () {
      final data = report(
        ReportKind.health,
        plants: [
          plant(1),
          plant(2, health: 'Other'),
        ],
      );
      expect(data.sections.first.rows.first, ['Healthy', '1', '50.0%']);
      expect(data.sections.first.rows[1], ['Needs Attention', '1', '50.0%']);
      expect(
        report(ReportKind.health, plants: []).sections.first.rows.first.last,
        'N/A',
      );
    },
  );
  test('outcomes keep full-scope and coverage definitions', () {
    final data = report(
      ReportKind.outcomes,
      outcomes: {
        'generated_on': '2026-10-19',
        'batches': [
          {'batch': '2026-09', 'total': 4, 'alive': 3, 'needs_attention': 1},
        ],
        'colleges': [
          {'college_name': 'CICS', 'total': 2, 'completed': 0},
        ],
        'health': [
          {'month': '2026-10', 'health': 'Dying', 'observations': 1},
        ],
      },
    );
    expect(
      data.metadata['Plant selection'],
      contains('page filters do not apply'),
    );
    expect(data.sections[0].rows.single.last, '75.0%');
    expect(data.sections[1].rows.single.last, '0.0%');
    expect(data.sections[1].note, contains('not on-time'));
    expect(data.sections[2].note, contains('not unique plants'));
    expect(data.sections[0].headers, contains('Needs Attention'));
    expect(data.sections[0].headers, isNot(contains('Unknown')));
    expect(data.sections[0].rows.single[3], '1');
    expect(() => report(ReportKind.outcomes), throwsStateError);
  });
  test('monitoring outcomes report missing health as Needs Attention', () {
    final sql = File(
      'supabase/migrations/202610220007_health_unknowns_to_needs_attention.sql',
    ).readAsStringSync();
    expect(sql, contains('as needs_attention'));
    expect(sql, contains("else 'Needs Attention'"));
    expect(sql, isNot(contains("'unknown'")));
  });
  test('long PDF notes remain intact across continuation rows', () {
    final text = List.filled(500, 'Long observation. ').join();
    final rows = ReportExportService.printableRows([
      ['ID', text],
    ]);
    expect(rows.map((r) => r[1].replaceFirst('(continued) ', '')).join(), text);
    expect(rows.length, greaterThan(1));
  });
  test(
    'history migration enforces session, roles and campus/college scope',
    () {
      final sql = File(
        'supabase/migrations/202610190005_report_inspection_history.sql',
      ).readAsStringSync();
      expect(sql, contains('require_app_session(p_session_token)'));
      expect(
        sql,
        contains(
          'p.campus_id = actor.campus_id and p.college_id = actor.college_id',
        ),
      );
      expect(sql, contains("at time zone 'Asia/Manila'"));
      expect(sql, contains('p_start_on'));
      expect(sql, contains('p_end_on'));
      expect(sql, contains('from public;'));
      expect(sql, contains('500)'));
      expect(sql, contains('report_validate_plants'));
      expect(sql, contains('p.archived_at is null'));
      expect(sql, contains("'inspection_team'"));
      expect(sql, contains('return not exists'));
    },
  );
  test('render all six PDF types including multi-page history', () async {
    final service = ReportExportService();
    final plants = List.generate(35, (i) => plant(i + 1));
    final history = List.generate(
      35,
      (i) => {
        'inspection_id': i + 1,
        'plant_id': i + 1,
        'observed_at': '2026-10-19T02:00:00Z',
        'inspector': 'Inspection Team',
        'health': 'Healthy',
        'growth_stage': 'Seedling',
        'observation': i == 0
            ? List.filled(150, 'Yellow leaves observed. ').join()
            : 'Plant inspected. No damage observed.',
      },
    );
    final outcomes = {
      'generated_on': '2026-10-19',
      'batches': [
        {'batch': '2026-09', 'total': 35, 'alive': 35, 'needs_attention': 0},
      ],
      'colleges': [
        {'college_name': 'CICS', 'total': 35, 'completed': 20},
      ],
      'health': [
        {'month': '2026-10', 'health': 'Healthy', 'observations': 35},
      ],
    };
    Directory('build/report_previews').createSync(recursive: true);
    for (final kind in ReportKind.values) {
      final bytes = await service.pdfBytes(
        report(kind, plants: plants, history: history, outcomes: outcomes),
      );
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      File('build/report_previews/${kind.name}.pdf').writeAsBytesSync(bytes);
    }
  });
}
