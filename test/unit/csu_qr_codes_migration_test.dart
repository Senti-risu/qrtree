import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new QR tag codes use the CSU prefix without rewriting old tags', () {
    final migration = File(
      'supabase/migrations/202610220002_csu_qr_codes.sql',
    ).readAsStringSync();

    expect(migration, contains("'CSU-%s-%s'"));
    expect(migration, contains("'format', 'CSU-YYYYMM-NNNNNN'"));
    expect(migration, contains('Existing codes'));
    expect(migration, isNot(contains('update public.qr_tag')));
  });

  test('existing codes are renamed while old labels remain scannable', () {
    final migration = File(
      'supabase/migrations/202610220003_rename_existing_qr_codes_to_csu.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('create table if not exists public.qr_tag_code_alias'),
    );
    expect(migration, contains('set qr_code_string = regexp_replace'));
    expect(migration, contains('public.staff_find_qr_tag_by_code'));
    expect(migration, contains('public.guest_view_plant_by_qr'));
    expect(migration, contains('alias.alias_code = normalized_code'));
    expect(migration, contains('require_app_session(p_session_token)'));
  });
}
