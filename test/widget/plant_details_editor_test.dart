import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/plant_details_editor_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/plant_details_editor.dart';

class FakeEditorRepository implements PlantDetailsEditorRepository {
  FakeEditorRepository({
    this.health = 'alive',
    this.archived = false,
    this.scientificName = 'Theobroma cacao',
  });
  final String scientificName;
  final String health;
  final bool archived;
  bool failSave = false;
  int saves = 0;
  PlantDetailsDraft? saved;
  @override
  Future<Map<String, dynamic>> load(int plantId) async => {
    'plant': {
      'plant_id': plantId,
      'classification_id': 1,
      'variety': 'Native',
      'tree_planter': 'Russel',
      'date_planted': '2026-01-01',
      'photo_url': '',
      'health_status': {'status_name': health},
      'archived_at': archived ? '2026-01-02' : null,
    },
    'location': {
      'planting_location_type': 'outside',
      'town_id': 1,
      'barangay_id': 1,
    },
    'classifications': [
      {
        'classification_id': 1,
        'plant_type': 'tree',
        'common_name': 'Cacao',
        'scientific_name': scientificName,
        'plant_classification_variety': [
          {'variety_id': 1, 'variety_name': 'Native'},
          {'variety_id': 2, 'variety_name': 'Improved variety'},
        ],
      },
      {
        'classification_id': 2,
        'plant_type': 'tree',
        'common_name': 'Mango',
        'scientific_name': 'Mangifera indica',
        'plant_classification_variety': [],
      },
    ],
    'campuses': [
      {'campus_id': 1, 'campus_name': 'CSU Lasam'},
    ],
    'towns': [
      {'town_id': 1, 'town_name': 'Lasam'},
      {'town_id': 2, 'town_name': 'Tuguegarao'},
    ],
    'barangays': [
      {'barangay_id': 1, 'town_id': 1, 'barangay_name': 'Centro 2'},
      {'barangay_id': 2, 'town_id': 2, 'barangay_name': 'Centro 1'},
    ],
  };
  @override
  Future<void> save(int plantId, PlantDetailsDraft draft) async {
    saves++;
    if (failSave) throw Exception('Failed to save');
    saved = draft;
  }

  @override
  Future<String> uploadPhoto(
    int userId,
    Uint8List bytes,
    String extension,
  ) async => 'https://example.com/plant.jpg';
}

Future<void> openEditor(
  WidgetTester tester,
  FakeEditorRepository repo, {
  double width = 390,
  double scale = 1,
  ValueChanged<bool?>? result,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    PlantDetailsEditor(plantId: 6, userId: 5, repository: repo),
              );
              result?.call(saved);
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Finder varietyField() => input('Variety (Optional)');

void main() {
  testWidgets('missing scientific name remains managed by University Admin', (
    tester,
  ) async {
    final repo = FakeEditorRepository(scientificName: '');
    await openEditor(tester, repo);
    final field = input('Scientific Name');
    await tester.ensureVisible(field);
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.saved?.classificationId, 1);
  });

  testWidgets('saved scientific name fills automatically and stays read only', (
    tester,
  ) async {
    await openEditor(tester, FakeEditorRepository());
    final field = input('Scientific Name');
    expect(tester.widget<TextField>(field).controller?.text, 'Theobroma cacao');
    expect(tester.widget<TextField>(field).readOnly, isTrue);
  });

  testWidgets('variety suggestions can be selected on mobile', (tester) async {
    final repo = FakeEditorRepository();
    await openEditor(tester, repo);
    final variety = varietyField();
    await tester.ensureVisible(variety);
    await tester.tap(variety);
    await tester.enterText(variety, 'Improved');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Improved variety').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(variety).controller?.text,
      'Improved variety',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.saved?.variety, 'Improved variety');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0, 1080.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('editor fits $width / $scale and saves more than location', (
        tester,
      ) async {
        final repo = FakeEditorRepository();
        bool? result;
        await openEditor(
          tester,
          repo,
          width: width,
          scale: scale,
          result: (v) => result = v,
        );
        expect(find.text('Update Plant Details'), findsOneWidget);
        expect(find.text('Native'), findsOneWidget);
        final variety = varietyField();
        await tester.ensureVisible(variety);
        await tester.enterText(variety, 'Improved variety');
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(repo.saved?.variety, 'Improved variety');
        expect(repo.saved?.treePlanter, 'Russel');
        expect(repo.saved?.classificationId, 1);
        expect(repo.saved?.locationChoice, 'outside');
        expect(repo.saved?.barangayId, 1);
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('failed save preserves entries and allows retry', (tester) async {
    final repo = FakeEditorRepository()..failSave = true;
    await openEditor(tester, repo);
    final variety = varietyField();
    await tester.ensureVisible(variety);
    await tester.enterText(variety, 'Improved variety');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.byType(PlantDetailsEditor), findsOneWidget);
    expect(
      tester.widget<TextField>(variety).controller?.text,
      'Improved variety',
    );
    repo.failSave = false;
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.saves, 2);
    expect(repo.saved?.variety, 'Improved variety');
  });
  testWidgets(
    'changing common name updates scientific name and classification',
    (tester) async {
      final repo = FakeEditorRepository();
      await openEditor(tester, repo, width: 600);
      final common = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<int> &&
            widget.key == const ValueKey('Common Name-1'),
      );
      await tester.ensureVisible(common);
      await tester.tap(common);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mango').last);
      await tester.pumpAndSettle();
      expect(find.text('Mangifera indica'), findsOneWidget);
      expect(
        tester.widget<TextField>(varietyField()).controller?.text,
        isEmpty,
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(repo.saved?.classificationId, 2);
    },
  );
  testWidgets('changing town requires a matching barangay before saving', (
    tester,
  ) async {
    final repo = FakeEditorRepository();
    await openEditor(tester, repo, width: 600);
    final town = find.byKey(const ValueKey('Planting Town-1'));
    await tester.ensureVisible(town);
    await tester.tap(town);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuguegarao').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.text('Select planting barangay.'), findsOneWidget);
    final barangay = find.byKey(const ValueKey('Planting Barangay-null'));
    await tester.ensureVisible(barangay);
    await tester.tap(barangay);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centro 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.saved?.townId, 2);
    expect(repo.saved?.barangayId, 2);
  });
  testWidgets('discard confirmation keeps entered changes when canceled', (
    tester,
  ) async {
    await openEditor(tester, FakeEditorRepository());
    final variety = varietyField();
    await tester.ensureVisible(variety);
    await tester.enterText(variety, 'Improved variety');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(variety).controller?.text,
      'Improved variety',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(PlantDetailsEditor), findsNothing);
  });
  for (final locked in [
    FakeEditorRepository(health: 'dead'),
    FakeEditorRepository(archived: true),
  ]) {
    testWidgets(
      'locked/archived record cannot save ${locked.health}/${locked.archived}',
      (tester) async {
        await openEditor(tester, locked);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save Changes'),
              )
              .onPressed,
          isNull,
        );
        expect(locked.saves, 0);
      },
    );
  }
  test(
    'details payload cannot move ownership, alter QR, or bypass inspection history',
    () {
      final params = PlantDetailsDraft(
        classificationId: 2,
        variety: ' Test ',
        treePlanter: ' Person ',
        datePlanted: DateTime(2026, 1, 2),
        photoUrl: '',
        locationChoice: 'outside',
        townId: 1,
        barangayId: 1,
      ).toParams(6);
      expect(params['p_variety'], 'Test');
      expect(params['p_date_planted'], '2026-01-02');
      expect(params['p_location_campus_id'], isNull);
      for (final field in [
        'p_campus_id',
        'p_college_id',
        'p_qr_tag_id',
        'p_health_status_id',
        'p_growth_status_id',
      ]) {
        expect(params.containsKey(field), isFalse);
      }
    },
  );
  test('migration retains scope, lock, validation and audit checks', () {
    final sql = File(
      'supabase/migrations/202610170001_update_plant_details.sql',
    ).readAsStringSync();
    for (final required in [
      "actor_account.role not in ('college_admin', 'inspection_team')",
      'p.campus_id = actor_account.campus_id',
      'p.college_id = actor_account.college_id',
      'p.archived_at is null for update',
      'is_dead_plant_status(target_plant.health_status_id)',
      'update_plant_physical_location(',
      'write_audit_event(',
      'revoke all on function',
      'notify pgrst',
    ]) {
      expect(sql, contains(required));
    }
  });
}
