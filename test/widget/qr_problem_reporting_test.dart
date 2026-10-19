import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_mobile_more_sheet.dart';
import 'package:flutter_application_1/widgets/qr_problem_dialog.dart';
import 'package:flutter_application_1/utils/user_facing_error.dart';

void main() {
  testWidgets('QR reporting requires a description and fits a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showQrProblemDialog(context, 12),
              child: const Text('Report'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Please describe the problem.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Missing QR'), findsOneWidget);
    expect(find.text('Wrong QR On Plant'), findsOneWidget);
    await tester.tap(find.text('Missing QR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Report QR Problem'), findsNothing);
  });

  for (final role in ['inspection_team', 'college_admin', 'campus_admin']) {
    testWidgets('$role QR report menu access', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showAppMobileMoreSheet(
                  context,
                  displayName: 'Staff',
                  displayRole: role,
                  role: role,
                ),
                child: const Text('Open More'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open More'));
      await tester.pumpAndSettle();
      expect(
        find.text('QR Problem Reports'),
        role == 'campus_admin' ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Register Plant'),
        role == 'campus_admin' ? findsNothing : findsOneWidget,
      );
      if (role == 'inspection_team') {
        expect(find.text('User Management'), findsNothing);
        expect(find.text('QR Management'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('duplicate and stale QR reports show actionable messages', () {
    expect(
      userFacingError('You already have a pending report for this QR label'),
      contains('My QR Reports'),
    );
    expect(
      userFacingError(
        'The plant label has changed or the plant is archived; dismiss this report',
      ),
      contains('Dismiss'),
    );
  });
}
