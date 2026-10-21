import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/plant_classification_catalog_screen.dart';
import 'package:flutter_application_1/services/plant_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

class FakePlantCatalog implements PlantClassificationCatalog {
  final entries = <Map<String, dynamic>>[];
  final plantTypes = <String>['Tree', 'Herb'];
  int creates = 0;

  @override
  Future<List<Map<String, dynamic>>> getClassifications() async => entries;

  @override
  Future<List<String>> getPlantTypes() async => plantTypes;

  @override
  Future<String> addPlantType(String name) async {
    final normalized = name.trim();
    if (!plantTypes.any(
      (type) => type.toLowerCase() == normalized.toLowerCase(),
    )) {
      plantTypes.add(normalized);
    }
    return plantTypes.firstWhere(
      (type) => type.toLowerCase() == normalized.toLowerCase(),
    );
  }

  @override
  Future<int> createPlantClassification({
    required String plantType,
    required String commonName,
    required String scientificName,
    String? variety,
  }) async {
    creates++;
    entries.add({
      'classification_id': creates,
      'plant_type': plantType,
      'common_name': commonName,
      'scientific_name': scientificName,
      'plant_classification_variety': variety == null
          ? []
          : [
              {'variety_id': creates, 'variety_name': variety},
            ],
    });
    return creates;
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  test('plant types are stored in a managed, extensible catalog', () {
    final sql = File(
      'supabase/migrations/202610220001_addable_plant_types.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains('create table if not exists public.plant_type_catalog'),
    );
    expect(
      sql,
      contains('alter column plant_type type text using plant_type::text'),
    );
    expect(sql, contains('public.university_admin_add_plant_type'));
    expect(sql, contains("actor.role is distinct from 'university_admin'"));
    expect(
      sql,
      contains('Add this plant type to the university catalog first'),
    );
  });

  testWidgets(
    'plant type dropdown supports adding types and excludes variety',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = FakePlantCatalog();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlantClassificationCatalogScreen(
            userId: 5,
            username: 'University Admin',
            role: 'university_admin',
            catalog: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add type'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Plant Type'), 'Fern');
      await tester.tap(find.text('Add Type'));
      await tester.pumpAndSettle();
      expect(catalog.plantTypes, contains('Fern'));
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>).first,
            )
            .initialValue,
        'Fern',
      );
      await tester.enterText(field('Common Name'), 'Narra');
      await tester.enterText(field('Scientific Name'), 'Pterocarpus indicus');
      await tester.tap(find.text('Add To Catalog'));
      await tester.pumpAndSettle();

      expect(catalog.creates, 1);
      expect(catalog.entries.single['plant_type'], 'Fern');
      expect(catalog.entries.single['common_name'], 'Narra');
      expect(catalog.entries.single['scientific_name'], 'Pterocarpus indicus');
      expect(catalog.entries.single['plant_classification_variety'], isEmpty);
      expect(find.text('Narra'), findsOneWidget);
      expect(find.text('Variety (Optional)'), findsNothing);
      expect(find.text('VARIETIES'), findsNothing);
      expect(find.text('Plant Classifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
