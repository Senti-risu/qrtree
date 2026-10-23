import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plant classifications reference the plant type catalog by ID', () {
    final migration = File(
      'supabase/migrations/202610230001_normalize_plant_classification_type.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('add column if not exists plant_type_id bigint'),
    );
    expect(migration, contains('set plant_type_id = t.plant_type_id'));
    expect(migration, contains('foreign key (plant_type_id)'));
    expect(
      migration,
      contains('references public.plant_type_catalog (plant_type_id)'),
    );
    expect(migration, contains('alter column plant_type_id set not null'));
    expect(
      migration,
      contains('create trigger plant_classification_type_sync_trigger'),
    );
    expect(migration, contains('raise exception'));
  });
}
