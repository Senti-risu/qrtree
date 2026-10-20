import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'package:flutter_application_1/widgets/forms/app_text_field.dart';
import 'registration_draft_flow_test.dart' as helpers;

class ScientificService extends helpers.LookupService {
  ScientificService({this.savedName = '', this.fail = false});
  final String savedName;
  final bool fail;
  String? submittedName;
  String? submittedCommonName;
  String? submittedPlantType;
  bool submitted = false;
  @override
  Future<List<Map<String, dynamic>>> getClassifications() async => [
    {
      'classification_id': 7,
      'plant_type': 'tree',
      'common_name': 'Mango',
      'scientific_name': savedName,
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
  Future<String> saveMissingScientificName(
    int classificationId,
    String name,
  ) async =>
      throw StateError('A separate scientific-name write must not be used.');
  @override
  Future<Map<String, dynamic>> registerPlantWithQr({
    required String locationType,
    int? locationCampusId,
    required int? classificationId,
    String? newPlantType,
    String? newCommonName,
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
    String? scientificName,
  }) async {
    submitted = true;
    submittedName = scientificName;
    submittedCommonName = newCommonName;
    submittedPlantType = newPlantType;
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
  for (final saved in [false, true]) {
    testWidgets(
      'scientific name ${saved ? 'auto-fills and stays protected' : 'is editable and submitted with registration'}',
      (tester) async {
        final service = ScientificService(
          savedName: saved ? 'Mangifera indica' : '',
        );
        await helpers.open(tester, draft(), width: 1440, service: service);
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        final field = tester.widget<AppTextField>(scientific());
        expect(field.readOnly, saved);
        if (saved) {
          expect(field.controller.text, 'Mangifera indica');
        } else {
          final input = find.descendant(
            of: scientific(),
            matching: find.byType(TextFormField),
          );
          await tester.ensureVisible(input);
          await tester.enterText(input, 'Mangifera indica');
          expect(field.controller.text, 'Mangifera indica');
        }
        final submit = find.widgetWithText(FilledButton, 'Register Plant');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(service.submitted, isTrue);
        expect(service.submittedName, saved ? isNull : 'Mangifera indica');
        expect(find.text('ECOTAG-TEST-99'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('failed registration keeps the entered name and draft', (
    tester,
  ) async {
    final service = ScientificService(fail: true);
    final drafts = draft();
    await helpers.open(tester, drafts, width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final field = tester.widget<AppTextField>(scientific());
    field.controller.text = 'Mangifera indica';
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.submitted, isTrue);
    expect(field.controller.text, 'Mangifera indica');
    expect(drafts.value, isNotNull);
    expect(find.text('ECOTAG-TEST-99'), findsNothing);
  });
  testWidgets('missing scientific name remains optional', (tester) async {
    final service = ScientificService();
    await helpers.open(tester, draft(), width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.submitted, isTrue);
    expect(service.submittedName, isNull);
  });
  testWidgets('new common and scientific names can be entered and submitted', (
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

    final commonName = find.byWidgetPredicate(
      (widget) =>
          widget is AppSearchableDropdown && widget.label == 'Common Name',
    );
    final commonNameInput = find.descendant(
      of: commonName,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(commonNameInput);
    await tester.enterText(commonNameInput, 'Banana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add "Banana"'));
    await tester.pumpAndSettle();

    final field = tester.widget<AppTextField>(scientific());
    expect(field.readOnly, isFalse);
    final scientificInput = find.descendant(
      of: scientific(),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(scientificInput);
    await tester.enterText(scientificInput, 'Musa acuminata');
    expect(field.controller.text, 'Musa acuminata');

    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(service.submitted, isTrue);
    expect(service.submittedPlantType, 'Tree');
    expect(service.submittedCommonName, 'Banana');
    expect(service.submittedName, 'Musa acuminata');
    expect(find.text('ECOTAG-TEST-99'), findsOneWidget);
  });
  testWidgets('mobile draft retains an entered scientific name', (
    tester,
  ) async {
    final drafts = draft();
    await helpers.open(tester, drafts, service: ScientificService());
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final field = tester.widget<AppTextField>(scientific());
    expect(field.readOnly, isFalse);
    field.controller.text = 'Mangifera indica';
    final save = find.byKey(const Key('save-registration-draft'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(drafts.value?['scientificName'], 'Mangifera indica');
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid scientific-name length blocks registration', (
    tester,
  ) async {
    final service = ScientificService();
    await helpers.open(tester, draft(), width: 1440, service: service);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    tester.widget<AppTextField>(scientific()).controller.text = List.filled(
      201,
      'a',
    ).join();
    final submit = find.widgetWithText(FilledButton, 'Register Plant');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.submitted, isFalse);
    expect(find.textContaining('200 printable characters'), findsWidgets);
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
  test(
    'new classifications are created atomically with plant registration',
    () {
      final sql = File(
        'supabase/migrations/202610200003_register_new_classifications.sql',
      ).readAsStringSync();
      expect(sql, contains('public.require_app_session(p_session_token)'));
      expect(sql, contains('p_campus_id is distinct from actor.campus_id'));
      expect(sql, contains('pg_advisory_xact_lock'));
      expect(sql, contains('public.register_plant_with_scientific_name'));
      expect(sql, contains('classification.created'));
    },
  );
}
