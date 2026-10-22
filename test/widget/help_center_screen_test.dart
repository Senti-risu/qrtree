import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/help_center_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('Help Center shows role-specific guides and common reminders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const HelpCenterScreen(
          userId: 1,
          username: 'inspector',
          role: 'inspection_team',
          campusId: 1,
          collegeId: 2,
        ),
      ),
    );

    expect(find.text('Help Center'), findsOneWidget);
    expect(find.text('Inspection Team'), findsNWidgets(2));
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Help'), findsNWidgets(2));
    expect(
      find.textContaining('download assigned plants first'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
