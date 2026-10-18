import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/admin_account.dart';
import 'package:flutter_application_1/services/super_admin_service.dart';
import 'package:flutter_application_1/screens/super_admin/create_account_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'registration_draft_flow_test.dart' as fixture;

class Accounts extends SuperAdminService {
  Accounts()
    : super(
        client: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int? createdCampus;
  @override
  Future<List<AdminScopeOption>> getCampuses() async => [
    const AdminScopeOption(id: 1, name: 'CSU Lasam'),
  ];
  @override
  Future<List<AdminAccount>> getAccounts(int actorUserId) async => [];
  @override
  Future<void> createAccount({
    required int actorUserId,
    required String username,
    required String password,
    required String role,
    int? campusId,
    int? collegeId,
  }) async {
    createdCampus = campusId;
  }
}

AppSearchableDropdown field(WidgetTester tester, String label) =>
    tester.widget<AppSearchableDropdown>(
      find.byWidgetPredicate(
        (w) => w is AppSearchableDropdown && w.label == label,
      ),
    );

void main() {
  testWidgets('registration Town and Barangay remain selection-only', (
    tester,
  ) async {
    await fixture.open(tester, fixture.MemoryDrafts(), width: 1600);
    expect(field(tester, 'Town').onCreate, isNull);
    expect(field(tester, 'Barangay').onCreate, isNull);
    expect(field(tester, 'Barangay').enabled, isFalse);
    field(tester, 'Town').onChanged('Lasam');
    await tester.pumpAndSettle();
    expect(field(tester, 'Barangay').enabled, isTrue);
    expect(field(tester, 'Barangay').items, contains('Centro'));
    field(tester, 'Barangay').onChanged('Centro');
    await tester.pumpAndSettle();
    expect(field(tester, 'Barangay').value, 'Centro');
    expect(find.textContaining('Add "'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account creation only permits an existing campus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = Accounts();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => CreateAdminAccountDialog(
                    actorUserId: 1,
                    service: service,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!('campus_admin');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new_admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();
    expect(service.createdCampus, isNull);
    expect(find.text('Select an available campus.'), findsOneWidget);
    final campus = field(tester, 'Campus');
    expect(campus.onCreate, isNull);
    final input = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is AppSearchableDropdown && w.label == 'Campus',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'Missing Campus');
    await tester.pumpAndSettle();
    expect(find.textContaining('Add "'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();
    expect(service.createdCampus, isNull);
    field(tester, 'Campus').onChanged('CSU Lasam');
    await tester.pumpAndSettle();
    expect(field(tester, 'Campus').value, 'CSU Lasam');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();
    expect(service.createdCampus, 1);
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
