import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/dashboard_page_header.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/app_filter_sheet.dart';
import 'package:flutter_application_1/widgets/app_mobile_navbar.dart';
import 'package:flutter_application_1/widgets/app_navigation_guard.dart';
import 'package:flutter_application_1/widgets/app_shell.dart';
import 'package:flutter_application_1/widgets/plant_summary_card.dart';
import 'package:flutter_application_1/widgets/registration_progress.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget shell(
    String role, {
    Widget? child,
    Widget? action,
    bool scanner = true,
  }) => AppShell(
    activeRoute: action == null ? '/plant-list' : '/register-plant',
    mobileTitle: action == null ? 'Plant Records' : 'Register Plant',
    mobileSubtitle: 'College plant monitoring',
    userId: 1,
    username: 'Test admin',
    role: role,
    campusId: 1,
    collegeId: 1,
    bottomAction: action,
    showQrButton: scanner,
    child: child ?? const SingleChildScrollView(child: Text('Plant records')),
  );

  for (final role in [
    'super_admin',
    'university_admin',
    'campus_admin',
    'college_admin',
    'inspection_team',
  ]) {
    for (final size in [
      const Size(320, 600),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets('$role navigation and scanner clearance at $size', (
        tester,
      ) async {
        viewport(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: shell(
              role,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(key: Key('last-item'), width: 100, height: 48),
              ),
            ),
          ),
        );
        final item = tester.getRect(find.byKey(const Key('last-item')));
        final scan = tester.getRect(find.byType(FloatingActionButton));
        expect(item.bottom, lessThan(scan.top));
        expect(find.text('Plants'), findsOneWidget);
        expect(find.text('More'), findsOneWidget);
        expect(find.byTooltip('Refresh'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(320, 600),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 1000),
  ]) {
    testWidgets('plant summary and four steps wrap at $size', (tester) async {
      viewport(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const RegistrationProgress(currentStep: 2),
                    const SizedBox(height: 12),
                    PlantSummaryCard(
                      name: 'Philippine Mango',
                      plantType: 'Fruit Tree',
                      role: 'college_admin',
                      scientificName: 'Mangifera indica',
                      plantedAt: 'Outside campus, Centro 2, Tuguegarao',
                      photo: const Icon(Icons.eco, size: 52),
                      status: const Chip(label: Text('Needs Attention')),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Step 3 of 4 · Photo'), findsOneWidget);
      expect(find.textContaining('Planted At:'), findsOneWidget);
      expect(find.text('Fruit Tree'), findsOneWidget);
      expect(find.textContaining('Managed By'), findsNothing);
      expect(find.textContaining('Last Inspected:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'floating filter panel footer remains reachable on short landscape',
    (tester) async {
      viewport(tester, const Size(844, 390));
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: AppFilterSheet(
                      title: 'Filter Plants',
                      applyLabel: 'Apply · 18 plants',
                      onReset: () {},
                      onApply: () => applied = true,
                      child: Column(
                        children: List.generate(20, (i) => Text('Status $i')),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Apply · 18 plants').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Apply · 18 plants'));
      expect(applied, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registration footer is above keyboard and navigation hides', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
          child: child!,
        ),
        home: shell(
          'inspection_team',
          scanner: false,
          action: FilledButton(
            onPressed: () {},
            child: const Text('Continue To Photo'),
          ),
        ),
      ),
    );
    expect(
      tester.getBottomLeft(find.text('Continue To Photo')).dy,
      lessThan(544),
    );
    expect(find.byType(AppMobileNavbar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 600), const Size(844, 390)]) {
    testWidgets(
      'large text registration actions stay above keyboard at $size',
      (tester) async {
        viewport(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: shell(
              'college_admin',
              scanner: false,
              action: AppCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Continue To Location'),
                    ),
                    OutlinedButton(onPressed: () {}, child: const Text('Back')),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('Continue To Location').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('Back')).dy,
          lessThan(size.height - 180),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('registration tab selection asks before replacing the form', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    var allow = false;
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          '/plant-list': (_) => const Scaffold(body: Text('Destination')),
        },
        home: AppNavigationGuard(
          canLeave: () async {
            checks++;
            return allow;
          },
          child: shell(
            'college_admin',
            scanner: false,
            action: const Text('Unsaved registration'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Plants'));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(find.text('Unsaved registration'), findsOneWidget);
    allow = true;
    await tester.tap(find.text('Plants'));
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
    expect(checks, 2);
  });

  testWidgets(
    'completed registration steps are selectable, future steps are not',
    (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RegistrationProgress(
              currentStep: 2,
              onStepSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('✓ Plant'));
      expect(selected, 0);
      selected = -1;
      await tester.tap(find.text('4 Review'));
      expect(selected, -1);
    },
  );

  testWidgets('desktop dashboard header has no manual refresh action', (
    tester,
  ) async {
    viewport(tester, const Size(1440, 1000));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: DashboardPageHeader(
            description: 'College Plant Overview',
            userRole: 'College Admin',
          ),
        ),
      ),
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('render a phone component preview', (tester) async {
    viewport(tester, const Size(390, 844));
    final font = FontLoader(AppTheme.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('preview'),
          child: shell(
            'college_admin',
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        const TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search plants',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Healthy · 2'),
                              selected: true,
                              onSelected: (_) {},
                            ),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.tune),
                              label: const Text('Filter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Register A Plant'),
                  ),
                  const SizedBox(height: 16),
                  PlantSummaryCard(
                    name: 'Mango',
                    plantType: 'Fruit Tree',
                    role: 'university_admin',
                    scientificName: 'Mangifera indica',
                    plantedAt: 'Outside campus, Centro 2, Lasam',
                    campus: 'CSU Lasam',
                    photo: const Icon(Icons.eco, color: Colors.green, size: 52),
                    status: const Chip(label: Text('Healthy')),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/layout_previews')
        ..createSync(recursive: true);
      File(
        '${folder.path}/mobile-design.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
