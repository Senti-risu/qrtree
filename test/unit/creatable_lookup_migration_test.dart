import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202610180004_creatable_location_lookups.sql',
  ).readAsStringSync();
  test(
    'lookup writes require an active session and restrict campus creation',
    () {
      expect(
        sql,
        contains('actor := public.require_app_session(p_session_token)'),
      );
      expect(sql, contains("actor.role is distinct from 'super_admin'"));
      expect(
        sql,
        contains(
          "raise exception 'Super Admin access required to add a campus'",
        ),
      );
      expect(sql, contains('revoke all on function public.app_add_lookup'));
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = public, extensions'));
    },
  );
  test(
    'lookup additions reuse names, serialize races and preserve town relationships',
    () {
      expect(sql, contains('pg_advisory_xact_lock'));
      expect(
        sql,
        contains(
          "case when p_kind = 'barangay' then p_town_id::text else '' end",
        ),
      );
      expect(sql, contains('b.town_id = p_town_id'));
      expect(
        sql,
        contains('insert into public.barangay(barangay_name, town_id)'),
      );
      expect(
        'if result_row is not null then return result_row; end if;'
            .allMatches(sql)
            .length,
        3,
      );
      expect(sql, contains('public.write_audit_event'));
      expect(sql.toLowerCase(), isNot(contains('update public.')));
      expect(sql.trim(), endsWith('commit;'));
    },
  );
}
