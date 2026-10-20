import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/services/plant_service.dart';
import 'package:flutter_application_1/screens/admin/registration/register_plant_screen.dart';
import 'package:flutter_application_1/services/registration_draft_store.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'package:flutter_application_1/widgets/forms/planting_campus_dropdown.dart';

class MemoryDrafts extends RegistrationDraftStore {
  Map<String, dynamic>? value;
  bool failSave = false;
  @override
  Future<Map<String, dynamic>?> read(String key) async => value;
  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    if (failSave) throw StateError('Device storage failed');
    value = data;
  }

  @override
  Future<void> discard(String key) async => value = null;
}

class LookupService extends PlantService {
  LookupService()
    : super(
        client: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  Future<List<Map<String, dynamic>>> getClassifications() async => [
    {
      'classification_id': 7,
      'plant_type': 'tree',
      'common_name': 'Mango',
      'scientific_name': 'Mangifera indica',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getCampuses() async => [
    {'campus_id': 1, 'campus_name': 'CSU Lasam'},
  ];
  @override
  Future<List<Map<String, dynamic>>> getColleges() async => [
    {'campus_id': 1, 'college_id': 2, 'college_name': 'Assigned College'},
  ];
  @override
  Future<List<Map<String, dynamic>>> getTowns() async => [
    {'town_id': 3, 'town_name': 'Lasam', 'zip_code': '3524'},
  ];
  @override
  Future<List<Map<String, dynamic>>> getBarangays() async => [
    {'barangay_id': 4, 'barangay_name': 'Centro', 'town_id': 3},
  ];
  @override
  Future<List<Map<String, dynamic>>> getGrowthStatuses() async => [
    {'growth_status_id': 5, 'growth_stage': 'seedling'},
  ];
  @override
  Future<List<Map<String, dynamic>>> getHealthStatuses() async => [
    {'health_status_id': 6, 'status_name': 'alive'},
  ];
}

Future<void> open(
  WidgetTester tester,
  MemoryDrafts drafts, {
  double width = 390,
  double scale = 1,
  String role = 'college_admin',
  PlantService? service,
  RouteFactory? onGenerateRoute,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: onGenerateRoute,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const Key('registration-preview'),
          child: child!,
        ),
      ),
      routes: {
        '/dashboard': (_) =>
            const Scaffold(body: Text('Dashboard destination')),
      },
      home: RegisterPlantScreen(
        userId: 5,
        username: 'Admin',
        role: role,
        campusId: 1,
        collegeId: 2,
        plantService: service ?? LookupService(),
        draftStore: drafts,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  Future<void> choose(WidgetTester tester, String label, String value) async {
    final field = tester.widget<AppSearchableDropdown>(
      find.byWidgetPredicate(
        (widget) => widget is AppSearchableDropdown && widget.label == label,
      ),
    );
    if (label == 'Common Name' && !field.items.contains(value)) {
      final created = await field.onCreate!(value);
      field.onChanged(created);
    } else {
      field.onChanged(value);
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'required plant and location fields block the next step until selected',
    (tester) async {
      await open(tester, MemoryDrafts());
      await tester.tap(find.text('Continue To Location'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4 · Plant'), findsOneWidget);
      final type = tester.widget<AppSearchableDropdown>(
        find.byWidgetPredicate(
          (w) => w is AppSearchableDropdown && w.label == 'Plant Type',
        ),
      );
      expect(type.errorText, 'Please select a plant type.');
      await choose(tester, 'Plant Type', 'Tree');
      await choose(tester, 'Common Name', 'Mango');
      await choose(tester, 'Growth Stage', 'Seedling');
      await choose(tester, 'Health Status', 'Healthy');
      await tester.tap(find.text('Continue To Location'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4 · Plant'), findsOneWidget);
      expect(find.text('Please select the date planted.'), findsOneWidget);
      final date = find.text('Select date');
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue To Location'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4 · Plant'), findsOneWidget);
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue To Location'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4 · Location'), findsOneWidget);
      await tester.tap(find.text('Continue To Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4 · Location'), findsOneWidget);
      expect(
        tester
            .widget<PlantingCampusDropdown>(find.byType(PlantingCampusDropdown))
            .errorText,
        isNotNull,
      );
      tester
          .widget<PlantingCampusDropdown>(find.byType(PlantingCampusDropdown))
          .onChanged!('outside');
      await tester.pumpAndSettle();
      await choose(tester, 'Town', 'Lasam');
      await tester.tap(find.text('Continue To Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4 · Location'), findsOneWidget);
      await choose(tester, 'Barangay', 'Centro');
      await tester.tap(find.text('Continue To Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 4 · Photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop submission highlights required fields without submitting',
    (tester) async {
      await open(tester, MemoryDrafts(), width: 1440);
      final submit = find.widgetWithText(FilledButton, 'Register Plant');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Please select the date planted.'), findsOneWidget);
      final requiredFields = tester
          .widgetList<AppSearchableDropdown>(find.byType(AppSearchableDropdown))
          .where((field) => field.isRequired);
      expect(requiredFields.length, 6);
      expect(requiredFields.every((field) => field.errorText != null), isTrue);
      expect(
        tester
            .widget<PlantingCampusDropdown>(find.byType(PlantingCampusDropdown))
            .errorText,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop registration is one continuous vertical form', (
    tester,
  ) async {
    await open(tester, MemoryDrafts(), width: 1440);
    expect(find.byKey(const Key('registration-step-header')), findsNothing);
    expect(find.text('Continue To Location'), findsNothing);
    expect(find.text('Plant Classification'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Plant Photo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Register Plant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('resume, save and leave registration at width $width', (
      tester,
    ) async {
      final drafts = MemoryDrafts()
        ..value = {
          'classificationId': 7,
          'variety': 'Native Mango',
          'planter': 'Russel',
        };
      await open(tester, drafts, width: width);
      expect(find.text('Resume saved registration?'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Native Mango'), findsOneWidget);
      expect(
        find.textContaining('Assigned College', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('save-registration-draft')));
      await tester.pumpAndSettle();
      expect(drafts.value?['classificationId'], 7);
      expect(drafts.value?['variety'], 'Native Mango');
      // Both desktop sidebar and mobile navbar use the same navigation guard.
      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();
      expect(find.text('Leave this registration?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Native Mango'), findsOneWidget);
      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save Draft'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard destination'), findsOneWidget);
      expect(drafts.value?['planter'], 'Russel');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed draft save keeps the registration open', (tester) async {
    final drafts = MemoryDrafts()
      ..value = {'variety': 'Unsaved'}
      ..failSave = true;
    await open(tester, drafts);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save Draft'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard destination'), findsNothing);
    expect(find.text('Unsaved'), findsOneWidget);
    expect(find.textContaining('Could not save the draft'), findsOneWidget);
  });

  testWidgets('discard removes saved draft before navigation', (tester) async {
    final drafts = MemoryDrafts()..value = {'variety': 'Discard me'};
    await open(tester, drafts);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(drafts.value, isNull);
    expect(find.text('Dashboard destination'), findsOneWidget);
  });
}
