import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String registrationFunction(String sql) {
  final start = sql.indexOf(
    'create or replace function public.register_plant_with_qr(',
  );
  final end = sql.indexOf(r'$$;', start);
  return sql.substring(start, end + 3).replaceAll('\r\n', '\n').trim();
}

void main() {
  test(
    'date requirement preserves authorization, weekly scheduling and historical records',
    () {
      final previous = File(
        'supabase/migrations/202610180001_weekly_plant_inspections.sql',
      ).readAsStringSync();
      final sql = File(
        'supabase/migrations/202610180002_require_registration_date.sql',
      ).readAsStringSync();
      const requiredCheck =
          "  if p_date_planted is null then\n    raise exception 'Date planted is required';\n  end if;\n";
      expect(
        registrationFunction(sql),
        registrationFunction(previous).replaceFirst(
          '  if p_date_planted is not null and p_date_planted > current_date then',
          '$requiredCheck  if p_date_planted is not null and p_date_planted > current_date then',
        ),
      );
      expect(sql, isNot(contains('alter table')));
      expect(
        sql,
        contains('revoke all on function public.register_plant_with_qr('),
      );
      expect(sql, contains('to anon, authenticated;'));
      expect(sql.trim(), endsWith('commit;'));
    },
  );
}
