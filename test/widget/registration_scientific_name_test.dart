import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'package:flutter_application_1/widgets/forms/app_text_field.dart';
import 'registration_draft_flow_test.dart' as helpers;
import 'package:flutter_application_1/widgets/plant_details_presentation.dart';

class ScientificService extends helpers.LookupService {
  ScientificService({this.savedName = 'Mangifera indica', this.fail = false});
  final String savedName;
  final bool fail;
  int? submittedClassificationId;
  bool submitted = false;
  @override
  Future<List<Map<String, dynamic>>> getClassifications() async => [
    {
      'classification_id': 7,
      'plant_type': 'tree',
      'common_name': 'Mango',
      'scientific_name': savedName,
      'plant_classification_variety': [],
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> findPossibleDuplicatePlants({
    required int classificationId,
    required int campusId,
    required int collegeId,
    required int townId,
    required int barangayId,
    String? variety,
    String? datePlanted,
    int limit = 10,
  }) async => [];
  @override
  Future<Map<String, dynamic>> registerPlantWithQr({
    required String locationType,
    int? locationCampusId,
    required int classificationId,
    required int campusId,
    required int collegeId,
    required int townId,
    required int barangayId,
    required int growthStatusId,
    required int healthStatusId,
    required int registeredBy,
    int? existingQrTagId,
    String? variety,
    String? datePlanted,
    String? treePlanter,
    String? photoUrl,
  }) async {
    submitted = true;
    submittedClassificationId = classificationId;
    if (fail) throw StateError('Registration failed.');
    return {'plant_id': 99, 'qr_tag_id': 9, 'qr_code_string': 'ECOTAG-TEST-99'};
  }
}

class ScientificDrafts extends helpers.MemoryDrafts {
  @override
  Future<void> complete(String key) async => value = null;
}

helpers.MemoryDrafts draft() => ScientificDrafts()
  ..value = {
    'classificationId': 7,
    'growthId': 5,
    'healthId': 6,
    'townId': 3,
    'barangayId': 4,
    'plantingCampus': '1',
    'datePlanted': '2026-01-01',
  };

Finder scientific() => find.byWidgetPredicate(
  (w) => w is AppTextField && w.label == 'Scientific Name',
);

void main() {
  testWidgets('closing post-registration details returns to plant records', (
    tester,
  ) async {
    await helpers.open(
      tester,
      draft(),
      width: 1440,
      service: ScientificService(),
      onGenerateRoute: (settings) {
        if (settings.name == '/plant-details') {
          return plantDetailsRoute<void>(
            settings: settings,
            platformIsWeb: true,
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Registered plant details'),
                leading: IconButton(
                  tooltip: 'Close Plant Details',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          );
        }
        if (settings.name == '/plant-list') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const Scaffold(body: Text('Plant Records destination')),
          );
        }
        return null;
      },
    );
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('View Plant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Registered plant details'), findsOneWidget);
    await tester.tap(find.byTooltip('Close Plant Details'));
    await tester.pumpAndSettle();
    expect(find.text('Plant Records destination'), findsOneWidget);
    expect(find.text('Registered plant details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scientific name is selected from the university catalog', (
    tester,
  ) async {
    final service = ScientificService();
    await helpers.open(tester, draft(), width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final field = tester.widget<AppTextField>(scientific());
    expect(field.readOnly, isTrue);
    expect(field.controller.text, 'Mangifera indica');
    final input = find.descendant(
      of: scientific(),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Not allowed');
    expect(field.controller.text, 'Mangifera indica');
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.submitted, isTrue);
    expect(service.submittedClassificationId, 7);
    expect(find.text('ECOTAG-TEST-99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed registration preserves the catalog name and draft', (
    tester,
  ) async {
    final service = ScientificService(fail: true);
    final drafts = draft();
    await helpers.open(tester, drafts, width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final field = tester.widget<AppTextField>(scientific());
    expect(field.readOnly, isTrue);
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.submitted, isTrue);
    expect(field.controller.text, 'Mangifera indica');
    expect(drafts.value, isNotNull);
    expect(find.text('ECOTAG-TEST-99'), findsNothing);
  });
  testWidgets('common names cannot be added from plant registration', (
    tester,
  ) async {
    final service = ScientificService();
    final drafts = draft();
    drafts.value = {
      ...drafts.value!,
      'classificationId': null,
      'plantType': 'Tree',
    };
    await helpers.open(tester, drafts, width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    final type = tester.widget<AppSearchableDropdown>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppSearchableDropdown && widget.label == 'Plant Type',
      ),
    );
    type.onChanged('Tree');
    await tester.pumpAndSettle();
    final commonName = tester.widget<AppSearchableDropdown>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppSearchableDropdown && widget.label == 'Common Name',
      ),
    );
    expect(commonName.allowCustomValue, isFalse);
    expect(commonName.items, ['Mango']);
    commonName.onChanged('Banana');
    await tester.pumpAndSettle();
    expect(find.text('Add "Banana"'), findsNothing);

    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(service.submitted, isFalse);
    expect(find.text('Please select a common name.'), findsOneWidget);
  });
  testWidgets('mobile draft keeps scientific name read only', (tester) async {
    final drafts = draft();
    await helpers.open(tester, drafts, service: ScientificService());
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final field = tester.widget<AppTextField>(scientific());
    expect(field.readOnly, isTrue);
    final save = find.byKey(const Key('save-registration-draft'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(drafts.value?['scientificName'], 'Mangifera indica');
    expect(tester.takeException(), isNull);
  });
  test(
    'scientific name migration keeps updates and registration atomic and scoped',
    () {
      final sql = File(
        'supabase/migrations/202610200001_registration_scientific_name.sql',
      ).readAsStringSync();
      expect(sql, contains('require_app_session(p_session_token)'));
      expect(sql, contains('p_campus_id is distinct from actor.campus_id'));
      expect(sql, contains('p_college_id is distinct from actor.college_id'));
      expect(sql, contains('p_registered_by is distinct from actor.user_id'));
      expect(sql, contains('for update'));
      expect(
        sql,
        contains("nullif(btrim(classification.scientific_name), '') is null"),
      );
      expect(sql, contains('Scientific name changed.'));
      expect(
        sql,
        contains(
          'return query select * from public.register_plant_at_location',
        ),
      );
      expect(sql, isNot(contains('exception when')));
    },
  );
  test('university catalog RPC owns classification creation', () {
    final sql = File(
      'supabase/migrations/202610210002_university_plant_catalog.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains('public.university_admin_create_plant_classification'),
    );
    expect(sql, contains("actor.role is distinct from 'university_admin'"));
    expect(sql, contains('classification.variety_created'));
    expect(sql, contains('public.validate_plant_catalog_variety'));
    expect(
      sql,
      contains(
        'revoke all on function public.register_plant_with_new_classification',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.register_plant_with_scientific_name',
      ),
    );
    expect(
      sql,
      contains(
        'revoke insert, update, delete on table public.plant_classification',
      ),
    );
  });
}
