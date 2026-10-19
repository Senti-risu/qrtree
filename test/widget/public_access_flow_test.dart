import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/auth/access_choice_screen.dart';
import 'package:flutter_application_1/screens/public/landing_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('landing page is usable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          '/': (_) => const LandingScreen(),
          '/login': (_) => const AccessChoiceScreen(),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Know every tree.\nCare for every campus.'),
      findsOneWidget,
    );
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('How would you like to continue?'), findsOneWidget);
    expect(find.text('Admin & Inspection Team'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access choice adapts to desktop and large text', (tester) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(1100, 760),
            textScaler: TextScaler.linear(1.5),
          ),
          child: AccessChoiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin & Inspection Team'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.textContaining('verified securely'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing page supports two-times mobile text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: LandingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Know every tree.\nCare for every campus.'),
      findsOneWidget,
    );
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
