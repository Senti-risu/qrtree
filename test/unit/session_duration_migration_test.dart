import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String loginFunction(String sql) {
  final start = sql.indexOf(
    'create or replace function public.login_user(p_username text, p_password text)',
  );
  final end = sql.indexOf(
    '\n'
    r'$$;',
    start,
  );
  // Line-ending/trailing-space differences do not change the SQL checks.
  return sql
      .substring(start, end + 4)
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .trim();
}

void main() {
  final sql = File(
    'supabase/migrations/202610170002_thirty_day_staff_sessions.sql',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  final previous = File(
    'supabase/migrations/202610130001_production_readiness.sql',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  test('thirty-day sessions preserve every existing secure login check', () {
    final expected = loginFunction(previous)
        .replaceFirst("interval '12 hours'", "interval '30 days'")
        .replaceFirst(
          "jsonb_build_object('session_duration_hours', 12)",
          "jsonb_build_object('session_duration_hours', 720, 'session_duration_days', 30)",
        );
    expect(loginFunction(sql), expected);
  });
  test('migration does not extend existing or revoked sessions', () {
    expect(sql, contains("now() + interval '30 days'"));
    expect(sql, isNot(contains('update public.app_sessions')));
    expect(
      sql,
      contains(
        'revoke all on function public.login_user(text, text) from public;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.login_user(text, text) to anon, authenticated;',
      ),
    );
    expect(sql.trim(), endsWith('commit;'));
  });
}
