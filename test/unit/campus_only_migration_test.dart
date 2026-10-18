import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202610190001_campus_only_lookup_creation.sql',
  ).readAsStringSync();
  test(
    'latest migration only permits campus creation by an active Super Admin',
    () {
      expect(
        sql,
        contains('actor := public.require_app_session(p_session_token)'),
      );
      expect(sql, contains("actor.role is distinct from 'super_admin'"));
      expect(sql, contains("p_kind is distinct from 'campus'"));
      expect(
        sql,
        contains("raise exception 'Only Campus creation is supported'"),
      );
      expect(sql, contains('insert into public.campus(campus_name)'));
      expect(sql.toLowerCase(), isNot(contains('insert into public.town')));
      expect(sql.toLowerCase(), isNot(contains('insert into public.barangay')));
      expect(sql.toLowerCase(), isNot(contains('delete from')));
      expect(sql.toLowerCase(), isNot(contains('update public.')));
    },
  );
  test(
    'campus replacement preserves signature, duplicate lock, audit and grants',
    () {
      expect(sql, contains('p_town_id integer default null'));
      expect(sql, contains('p_zip_code text default null'));
      expect(
        sql,
        contains("hashtextextended('campus::' || lower(clean_name), 0)"),
      );
      expect(
        sql,
        contains('if result_row is not null then return result_row; end if;'),
      );
      expect(sql, contains('public.write_audit_event'));
      expect(sql, contains('set search_path = public, extensions'));
      expect(
        sql,
        contains(
          'revoke all on function public.app_add_lookup(text, text, text, integer, text) from public',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.app_add_lookup(text, text, text, integer, text) to anon, authenticated',
        ),
      );
    },
  );
}
