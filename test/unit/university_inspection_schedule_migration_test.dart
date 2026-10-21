import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('university schedule change updates existing and new plant schedules', () {
    final migration = File(
      'supabase/migrations/202610220009_university_inspection_schedule.sql',
    ).readAsStringSync();
    final fix = File(
      'supabase/migrations/202610220010_fix_university_inspection_schedule.sql',
    ).readAsStringSync();
    final reset = File(
      'supabase/migrations/202610220012_reset_university_inspection_dates.sql',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(migration, contains('interval_days between 1 and 3650'));
    expect(
      migration,
      contains('actor.role is distinct from \'university_admin\''),
    );
    expect(
      migration,
      contains('set inspection_interval_days = p_interval_days'),
    );
    expect(migration, contains('coalesce('));
    expect(
      migration,
      contains('create trigger apply_university_inspection_interval'),
    );
    expect(migration, contains('before insert on public.plant'));
    expect(migration, contains('recalculated_existing_plants'));
    expect(fix, contains('where p.archived_at is null'));
    expect(fix, contains('and not public.is_dead_plant_status'));
    expect(fix, contains('set inspection_interval_days = p_interval_days'));
    expect(
      reset,
      matches(
        RegExp(
          r"next_inspection_due_on\s*=\s*\(now\(\) at time zone 'Asia/Manila'\)::date \+ p_interval_days",
        ),
      ),
    );
    expect(reset, contains('where p.archived_at is null'));
    expect(reset, contains('and not public.is_dead_plant_status'));
    expect(reset, contains("'reset_from_change_date', true"));
    expect(reset, contains('from public.inspection_schedule_settings s'));
    expect(reset, contains('next_inspection_due_on ='));
  });
}
