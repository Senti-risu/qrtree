import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy enums are converted to text and removed without touching roles',
    () {
      final migration = File(
        'supabase/migrations/202610220008_remove_legacy_enums.sql',
      ).readAsStringSync();

      expect(migration, contains("'plant_type_enum'"));
      expect(migration, contains("'health_status_enum'"));
      expect(migration, contains("'growth_stage_enum'"));
      expect(migration, contains("'qr_status_enum'"));
      expect(migration, contains('using %I::text'));
      expect(migration, contains('drop type public.%I'));
      expect(migration, contains("'pg_policy'::regclass"));
      expect(migration, contains('drop policy %I on %I.%I'));
      expect(migration, contains('create policy %I on %I.%I'));
      expect(migration, isNot(contains("'user_role'")));
    },
  );
}
