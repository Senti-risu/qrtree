import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/inspection_reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/app_role.dart';
import 'package:flutter_application_1/services/persistent_session.dart';
import 'package:flutter_application_1/screens/auth/session_bootstrap_screen.dart';
import 'package:flutter_application_1/screens/public/landing_screen.dart';

void main() {
  const user = SessionIdentity(
    userId: 5,
    username: 'Admin',
    role: AppRole.collegeAdmin,
    campusId: 1,
    collegeId: 2,
  );
  Widget app(
    Future<SessionIdentity?> Function() restore, {
    Future<void> Function()? forget,
  }) => MaterialApp(
    home: SessionBootstrapScreen(
      restoreSession: restore,
      forgetSession: forget,
    ),
    routes: {
      '/dashboard': (_) => const Scaffold(body: Text('Dashboard loaded')),
      '/staff-login': (_) => const Scaffold(body: Text('Login required')),
      '/inspections': (_) =>
          const Scaffold(body: Text('Inspection queue loaded')),
    },
  );

  for (final payload in ['5', '99']) {
    testWidgets('reminder launch validates account $payload', (tester) async {
      InspectionReminders.instance.launchPayload = payload;
      addTearDown(() => InspectionReminders.instance.launchPayload = null);
      await tester.pumpWidget(app(() async => user));
      await tester.pumpAndSettle();
      expect(
        find.text(
          payload == '5' ? 'Inspection queue loaded' : 'Dashboard loaded',
        ),
        findsOneWidget,
      );
      expect(InspectionReminders.instance.launchPayload, isNull);
    });
  }

  testWidgets('valid remembered session bypasses login', (tester) async {
    await tester.pumpWidget(app(() async => user));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard loaded'), findsOneWidget);
    expect(find.text('Login required'), findsNothing);
  });
  testWidgets('first-time visitors retain the landing page', (tester) async {
    await tester.pumpWidget(app(() async => null));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
  });
  testWidgets('rejected sessions go to staff sign-in', (tester) async {
    await tester.pumpWidget(app(() async => throw const SessionRejected()));
    await tester.pumpAndSettle();
    expect(find.text('Login required'), findsOneWidget);
  });
  testWidgets('network failure offers retry without entering dashboard', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      app(() async {
        if (++checks == 1) throw Exception('network timeout');
        return user;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard loaded'), findsNothing);
    expect(find.text('Unable To Check Saved Sign-In'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard loaded'), findsOneWidget);
  });
  testWidgets('manual sign-in first forgets the saved token', (tester) async {
    var forgotten = false;
    await tester.pumpWidget(
      app(
        () async => throw Exception('network'),
        forget: () async => forgotten = true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget Saved Sign-In And Log In'));
    await tester.pumpAndSettle();
    expect(forgotten, isTrue);
    expect(find.text('Login required'), findsOneWidget);
  });
}
