import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/plant_classification_catalog_screen.dart';
import 'package:flutter_application_1/services/plant_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';

class FakePlantCatalog implements PlantClassificationCatalog {
  final entries = <Map<String, dynamic>>[];
  final plantTypes = <String>['Tree', 'Herb'];
  int creates = 0;
  int updates = 0;
  int deletes = 0;

  @override
  Future<List<Map<String, dynamic>>> getClassifications() async =>
      entries.where((entry) => entry['is_active'] != false).toList();

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
  Future<String> updatePlantType({
    required String currentName,
    required String updatedName,
  }) async {
    final index = plantTypes.indexOf(currentName);
    if (index < 0) throw StateError('Plant type not found.');
    plantTypes[index] = updatedName;
    for (final entry in entries) {
      if (entry['plant_type'] == currentName) {
        entry['plant_type'] = updatedName;
      }
    }
    return updatedName;
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
      'is_active': true,
      'plant_classification_variety': variety == null
          ? []
          : [
              {'variety_id': creates, 'variety_name': variety},
            ],
    });
    return creates;
  }

  @override
  Future<void> updatePlantClassification({
    required int classificationId,
    required String plantType,
    required String commonName,
    required String scientificName,
  }) async {
    updates++;
    final entry = entries.firstWhere(
      (entry) => entry['classification_id'] == classificationId,
    );
    entry['plant_type'] = plantType;
    entry['common_name'] = commonName;
    entry['scientific_name'] = scientificName;
  }

  @override
  Future<void> deletePlantClassification({
    required int classificationId,
  }) async {
    deletes++;
    final entry = entries.firstWhere(
      (entry) => entry['classification_id'] == classificationId,
    );
    entry['is_active'] = false;
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  test('removing a classification is a soft delete', () {
    final sql = File(
      'supabase/migrations/202610220005_soft_delete_plant_classifications.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains(
        'add column if not exists is_active boolean not null default true',
      ),
    );
    expect(sql, contains("set is_active = false"));
    expect(sql, contains('create trigger plant_classification_must_be_active'));
    expect(sql, contains('university_admin_delete_plant_classification'));
    expect(
      sql.toLowerCase(),
      isNot(contains('delete from public.plant_classification')),
    );
  });

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

  test('editing a plant type updates saved classifications safely', () {
    final sql = File(
      'supabase/migrations/202610220011_edit_plant_types.sql',
    ).readAsStringSync();
    expect(sql, contains('public.university_admin_update_plant_type'));
    expect(sql, contains("actor.role is distinct from 'university_admin'"));
    expect(sql, contains('A plant type with this name already exists'));
    expect(sql, contains('update public.plant_classification'));
    expect(sql, contains("'plant_type.updated'"));
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
      expect(find.byType(AppPageHeader), findsOneWidget);
      final pageHeader = tester.getRect(find.text('University Plant Catalog'));
      final createForm = tester.getRect(find.text('Create Catalog Entry'));
      expect(createForm.top, greaterThan(pageHeader.bottom));

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
      await tester.tap(find.text('Edit type'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Plant Type'), 'Fern Tree');
      await tester.tap(find.text('Save Plant Type'));
      await tester.pumpAndSettle();
      expect(catalog.plantTypes, contains('Fern Tree'));
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>).first,
            )
            .initialValue,
        'Fern Tree',
      );
      await tester.enterText(field('Common Name'), 'Narra');
      await tester.enterText(field('Scientific Name'), 'Pterocarpus indicus');
      await tester.tap(find.text('Add To Catalog'));
      await tester.pumpAndSettle();

      expect(catalog.creates, 1);
      expect(catalog.entries.single['plant_type'], 'Fern Tree');
      expect(catalog.entries.single['common_name'], 'Narra');
      expect(catalog.entries.single['scientific_name'], 'Pterocarpus indicus');
      expect(catalog.entries.single['plant_classification_variety'], isEmpty);
      expect(find.text('Narra'), findsOneWidget);
      expect(find.text('Variety (Optional)'), findsNothing);
      expect(find.text('VARIETIES'), findsNothing);
      expect(find.text('Plant Classifications'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byTooltip('Edit Narra'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(find.byTooltip('Edit Narra'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Common Name').last, 'Narra Tree');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(catalog.updates, 1);
      expect(catalog.entries.single['common_name'], 'Narra Tree');
      expect(find.text('Narra Tree'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Delete Narra Tree'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Existing plants and their saved data will not be deleted.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(catalog.deletes, 0);

      await tester.tap(find.byTooltip('Delete Narra Tree'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Catalog'));
      await tester.pumpAndSettle();
      expect(catalog.deletes, 1);
      expect(catalog.entries.single['is_active'], isFalse);
      expect(catalog.entries, hasLength(1));
      expect(find.text('Narra Tree'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog type filter is a dropdown beside search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = FakePlantCatalog()
      ..entries.addAll([
        {
          'classification_id': 1,
          'plant_type': 'Tree',
          'common_name': 'Mango',
          'scientific_name': 'Mangifera indica',
          'plant_classification_variety': [],
        },
        {
          'classification_id': 2,
          'plant_type': 'Herb',
          'common_name': 'Basil',
          'scientific_name': 'Ocimum basilicum',
          'plant_classification_variety': [],
        },
      ]);
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

    final search = find.byKey(const ValueKey('catalog-search'));
    final typeFilter = find.byKey(const ValueKey('catalog-type-filter-null'));
    expect(
      (tester.getTopLeft(search).dy - tester.getTopLeft(typeFilter).dy).abs(),
      lessThan(8),
    );
    expect(find.text('All types'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);

    await tester.tap(typeFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tree').last);
    await tester.pumpAndSettle();

    expect(find.text('Mango'), findsOneWidget);
    expect(find.text('Basil'), findsNothing);
    expect(find.text('All types'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog content adapts to a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = FakePlantCatalog()
      ..entries.add({
        'classification_id': 1,
        'plant_type': 'Tree',
        'common_name': 'Mango',
        'scientific_name': 'Mangifera indica',
        'plant_classification_variety': [],
      });

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

    expect(find.text('Create Catalog Entry'), findsOneWidget);
    expect(find.text('Mango'), findsOneWidget);
    expect(find.byTooltip('Edit Mango'), findsOneWidget);
    expect(find.byTooltip('Delete Mango'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('mobile catalog form actions align at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlantClassificationCatalogScreen(
            userId: 5,
            username: 'University Admin',
            role: 'university_admin',
            catalog: FakePlantCatalog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addType = find.widgetWithText(OutlinedButton, 'Add type');
      final editType = find.widgetWithText(OutlinedButton, 'Edit type');
      final addToCatalog = find.widgetWithText(FilledButton, 'Add To Catalog');
      await tester.ensureVisible(addToCatalog);

      final addTypeRect = tester.getRect(addType);
      final editTypeRect = tester.getRect(editType);
      final submitRect = tester.getRect(addToCatalog);
      expect(addTypeRect.top, editTypeRect.top);
      expect(addTypeRect.width, closeTo(editTypeRect.width, 1));
      expect(addTypeRect.left, lessThan(editTypeRect.left));
      expect(submitRect.width, greaterThan(addTypeRect.width));
      expect(tester.takeException(), isNull);
    });
  }
}
