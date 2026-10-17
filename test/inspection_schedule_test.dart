import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/inspection_schedule.dart';

String function(String sql, String name) {
  final start = sql.indexOf('create or replace function public.$name(');
  final end = sql.indexOf(r'$$;', start);
  return sql.substring(start, end + 3).replaceAll('\r\n', '\n').trim();
}

void main() {
  test(
    'inspection default is seven days while custom schedules are preserved',
    () {
      expect(InspectionSchedule.intervalDays({}), 7);
      expect(
        InspectionSchedule.intervalDays({'inspection_interval_days': 0}),
        7,
      );
      expect(
        InspectionSchedule.intervalDays({'inspection_interval_days': 14}),
        14,
      );
    },
  );

  test('weekly inspection is due on day seven and overdue on day eight', () {
    final plant = {'last_inspected_on': '2026-10-18'};
    expect(
      InspectionSchedule.isOverdue(plant, now: DateTime(2026, 10, 25, 23)),
      isFalse,
    );
    expect(
      InspectionSchedule.isOverdue(plant, now: DateTime(2026, 10, 26)),
      isTrue,
    );
  });

  test('never inspected plants use their planting or registration date', () {
    expect(
      InspectionSchedule.isOverdue({
        'date_planted': '2026-10-18',
      }, now: DateTime(2026, 10, 26)),
      isTrue,
    );
    expect(
      InspectionSchedule.isOverdue({
        'created_at': '2026-10-18T20:00:00',
      }, now: DateTime(2026, 10, 26)),
      isTrue,
    );
  });

  test('saved due dates and custom intervals override the weekly fallback', () {
    expect(
      InspectionSchedule.isOverdue({
        'last_inspected_on': '2026-10-18',
        'inspection_interval_days': 14,
      }, now: DateTime(2026, 10, 26)),
      isFalse,
    );
    expect(
      InspectionSchedule.isOverdue({
        'last_inspected_on': '2026-10-18',
        'next_inspection_due_on': '2026-11-10',
      }, now: DateTime(2026, 10, 26)),
      isFalse,
    );
  });

  test(
    'Dead and archived plants are never counted as routine overdue work',
    () {
      final plant = {'next_inspection_due_on': '2026-01-01'};
      expect(
        InspectionSchedule.isOverdue({
          ...plant,
          'health_status': {'status_name': 'dead'},
        }),
        isFalse,
      );
      expect(
        InspectionSchedule.isOverdue({...plant, 'archived_at': '2026-02-01'}),
        isFalse,
      );
    },
  );

  final sql = File(
    'supabase/migrations/202610180001_weekly_plant_inspections.sql',
  ).readAsStringSync();
  test(
    'weekly migration preserves registration and reopening authorization',
    () {
      final oldRegistration = File(
        'supabase/migrations/202610150002_plant_physical_location.sql',
      ).readAsStringSync();
      final oldReopen = File(
        'supabase/migrations/202610160001_dead_plant_lock.sql',
      ).readAsStringSync();
      expect(
        function(sql, 'register_plant_with_qr'),
        function(
          oldRegistration,
          'register_plant_with_qr',
        ).replaceAll(RegExp(r'\b90\b'), '7'),
      );
      expect(
        function(sql, 'college_admin_reopen_dead_plant'),
        function(oldReopen, 'college_admin_reopen_dead_plant').replaceFirst(
          'coalesce(p.inspection_interval_days, 90)',
          'coalesce(p.inspection_interval_days, 7)',
        ),
      );
    },
  );

  test(
    'weekly migration updates only active old-default schedules and is transactional',
    () {
      expect(
        sql,
        contains('alter column inspection_interval_days set default 7'),
      );
      expect(sql, contains('where p.inspection_interval_days = 90'));
      expect(sql, contains('and p.archived_at is null'));
      expect(
        sql,
        contains('and not public.is_dead_plant_status(p.health_status_id)'),
      );
      expect(
        sql,
        contains(
          'coalesce(p.last_inspected_on, p.date_planted, p.created_at::date, current_date) + 7',
        ),
      );
      expect(sql.trim(), endsWith('commit;'));
    },
  );
}
