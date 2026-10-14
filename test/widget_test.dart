import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/account_profile_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_mobile_more_sheet.dart';
import 'package:flutter_application_1/widgets/app_mobile_navbar.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/app_shell.dart';
import 'package:flutter_application_1/widgets/guest_mobile_navbar.dart';

void main() {
  testWidgets('EcoTag page header renders its content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPageHeader(
            title: 'Dashboard',
            subtitle: 'University-wide plant overview',
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('University-wide plant overview'), findsOneWidget);
  });

  testWidgets('EcoTag theme uses compact bundled typography', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              Text('100% of total plants'),
              Text('Aug 22, 2026'),
              Text('ECOTAG-202610-000001'),
            ],
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    final styles = <TextStyle?>[
      theme.textTheme.displayLarge,
      theme.textTheme.displayMedium,
      theme.textTheme.displaySmall,
      theme.textTheme.headlineLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ];

    for (final style in styles) {
      expect(style, isNotNull);
      expect(style!.fontFamily, AppTheme.fontFamily);
      expect(style.letterSpacing, 0);
      expect(style.wordSpacing, 0);
      expect(
        style.fontFeatures,
        contains(const FontFeature.proportionalFigures()),
      );
    }

    expect(find.text('100% of total plants'), findsOneWidget);
    expect(find.text('Aug 22, 2026'), findsOneWidget);
    expect(find.text('ECOTAG-202610-000001'), findsOneWidget);
  });

  testWidgets('college admin mobile More menu exposes scoped actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: const Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: AppMobileNavbar(
              activeRoute: '/dashboard',
              userId: 7,
              username: 'college.admin',
              role: 'college_admin',
              campusId: 2,
              collegeId: 4,
              canScanQr: true,
              displayName: 'College Administrator With A Long Name',
              displayRole: 'College Admin',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Inspections'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Register Plant'), findsOneWidget);
    expect(find.text('QR Management'), findsOneWidget);
    expect(find.text('User Management'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile AppShell removes profile avatar from the top bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AppShell(
          activeRoute: '/dashboard',
          mobileTitle: 'Dashboard',
          mobileSubtitle: 'Campus overview',
          userId: 3,
          username: 'campus.admin',
          role: 'campus_admin',
          showQrButton: false,
          child: Text('Mobile content'),
        ),
      ),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile profile shows assignment names instead of internal IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppMobileProfileSheet(
                context,
                username: 'lasamcicsadmin',
                displayName: 'Lasam CICS Admin',
                displayRole: 'College Admin',
                role: 'college_admin',
                loadScopeNames: () async => const AccountScopeNames(
                  campusName: 'CSU Lasam',
                  collegeName: 'College of Information Technology',
                ),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();

    expect(find.text('Role'), findsOneWidget);
    expect(find.text('College Admin'), findsWidgets);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('CSU Lasam'), findsOneWidget);
    expect(find.text('College'), findsOneWidget);
    expect(find.text('College of Information Technology'), findsOneWidget);
    expect(find.text('Account ID'), findsNothing);
    expect(find.text('Campus ID'), findsNothing);
    expect(find.text('College ID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campus admin More menu hides college-only management actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: AppMobileNavbar(
            activeRoute: '/dashboard',
            userId: 9,
            username: 'campus.admin',
            role: 'campus_admin',
            campusId: 2,
            displayName: 'Campus Administrator',
            displayRole: 'Campus Admin',
          ),
        ),
      ),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Register Plant'), findsNothing);
    expect(find.text('QR Management'), findsNothing);
    expect(find.text('User Management'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile shell supports two-times accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: AppShell(
            activeRoute: '/dashboard',
            mobileTitle: 'Inspection Dashboard',
            mobileSubtitle: 'Assigned college plant monitoring',
            userId: 11,
            username: 'inspection.user',
            role: 'inspection_team',
            campusId: 2,
            collegeId: 4,
            showQrButton: true,
            child: Text('Accessible mobile content'),
          ),
        ),
      ),
    );

    expect(find.text('Inspection Dashboard'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest mobile navigation only shows Home, Scan, and Account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: const SizedBox.expand(),
              floatingActionButton: const FloatingActionButton(
                onPressed: null,
                child: Icon(Icons.qr_code_scanner_rounded),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: GuestMobileNavbar(
                selectedIndex: selected,
                onHome: () => setState(() => selected = 0),
                onAccount: () => setState(() => selected = 1),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Plants'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Inspections'), findsNothing);
    expect(find.text('More'), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pump();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
