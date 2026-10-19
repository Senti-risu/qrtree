import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/app_workspace_page.dart';
import 'package:flutter_application_1/widgets/compact_filter_panel.dart';
import 'package:flutter_application_1/widgets/full_width_data_table.dart';
import 'package:flutter_application_1/widgets/app_shell.dart';
import 'package:flutter_application_1/widgets/app_sidebar.dart';
import 'package:flutter_application_1/widgets/app_top_navbar.dart';

const pages = {
  'Dashboard': <String>[],
  'Registration': <String>[],
  'Plant Records': ['Register Plant'],
  'QR Management': ['Generate', 'Print', 'Scan'],
  'Inspection Team Accounts': ['Archived', 'Create Account'],
  'Reports & Analytics': ['Export PDF'],
  'Activity Log': <String>[],
};

void main() {
  testWidgets(
    'main content scrolls through header and results with navigation fixed',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(
            activeRoute: '/qr-management',
            mobileTitle: 'QR Management',
            userId: 1,
            username: 'Admin',
            role: 'college_admin',
            child: AppWorkspacePage(
              header: const SizedBox(
                key: Key('scrolling-heading'),
                height: 140,
                child: Text('QR Management'),
              ),
              tools: const SizedBox(
                height: 120,
                child: Text('Search And Filters'),
              ),
              body: ListView.builder(
                key: const Key('main-results'),
                itemCount: 40,
                itemExtent: 70,
                itemBuilder: (_, index) => Text('QR Item $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scrolling-heading')), findsOneWidget);
      final navbarRect = tester.getRect(find.byType(AppTopNavbar));
      final sidebarRect = tester.getRect(find.byType(AppSidebar));
      await tester.drag(
        find.byKey(const Key('main-results')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('scrolling-heading')).hitTestable(),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('QR Item 39'),
        500,
        scrollable: find.descendant(
          of: find.byKey(const Key('main-results')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('QR Item 39').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byType(AppTopNavbar)), navbarRect);
      expect(tester.getRect(find.byType(AppSidebar)), sidebarRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render shared QR and account workspace previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/DMSans-Variable.ttf'))).load();
    await (FontLoader(
      AppTheme.headingFontFamily,
    )..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final qr in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: const Key('preview'),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: AppWorkspacePage(
                  header: AppPageHeader(
                    title: qr ? 'QR Management' : 'Inspection Team Accounts',
                    subtitle: qr
                        ? 'Generate, print, scan, and monitor EcoTag QR codes'
                        : 'Manage inspection accounts for your college.',
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {},
                          icon: Icon(qr ? Icons.qr_code : Icons.person_add_alt),
                          label: Text(qr ? 'Generate QR' : 'Create Account'),
                        ),
                      ],
                    ),
                  ),
                  tools: AppToolbarCard(
                    child: CompactFilterPanel(
                      search: TextField(
                        decoration: InputDecoration(
                          hintText: qr
                              ? 'Search QR code or ID'
                              : 'Search accounts',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      controls: [
                        OutlinedButton(
                          onPressed: () {},
                          child: Text(qr ? 'All Statuses' : 'Filters'),
                        ),
                      ],
                      choices: const [],
                      resultSummary: '1 of 1 results',
                    ),
                  ),
                  body: AppTablePanel(
                    child: FullWidthDataTable(
                      columns: [
                        DataColumn(label: Text(qr ? 'QR CODE' : 'ACCOUNT')),
                        const DataColumn(label: Text('STATUS')),
                        const DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: [
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                qr ? 'ECOTAG-202610-000020' : 'Inspection Team',
                              ),
                            ),
                            DataCell(Text(qr ? 'Available' : 'Active')),
                            DataCell(
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {},
                                    child: Text(qr ? 'Print' : 'Edit'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {},
                                    child: Text(
                                      qr ? 'Retire label' : 'Archive',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/layout_previews').createSync(recursive: true);
        File(
          'build/layout_previews/workspace-${qr ? 'qr' : 'accounts'}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
  for (final page in pages.entries) {
    for (final width in [320.0, 600.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${page.key} shared layout $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var invoked = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 800),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppWorkspacePage(
                      header: AppPageHeader(
                        key: const Key('header'),
                        title: page.key,
                        subtitle: 'Review and manage your assigned records.',
                        trailing: page.value.isEmpty
                            ? null
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final action in page.value)
                                    FilledButton(
                                      onPressed: () => invoked = true,
                                      child: Text(action),
                                    ),
                                ],
                              ),
                      ),
                      tools: AppToolbarCard(
                        key: const Key('tools'),
                        child: CompactFilterPanel(
                          search: const TextField(
                            decoration: InputDecoration(
                              hintText: 'Search records',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          controls: [
                            OutlinedButton(
                              onPressed: () {},
                              child: const Text('Filters'),
                            ),
                          ],
                          choices: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: true,
                              onSelected: (_) {},
                            ),
                          ],
                          resultSummary: '1 of 1 results',
                        ),
                      ),
                      body: const AppEmptyState(
                        title: 'No matching records',
                        message: 'Try a different filter.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final header = tester.getRect(find.byKey(const Key('header')));
          final tools = tester.getRect(find.byKey(const Key('tools')));
          final combined = tester.getRect(
            find.byKey(const ValueKey('workspace-heading-filters')),
          );
          expect(combined.width, width - 32);
          expect(combined.contains(header.topLeft), isTrue);
          expect(combined.contains(tools.bottomRight), isTrue);
          expect(header.left, tools.left);
          expect(header.width, tools.width);
          expect(tools.top - header.bottom, 41);
          for (final action in page.value) {
            await tester.ensureVisible(find.text(action));
            await tester.tap(find.text(action));
            expect(invoked, isTrue);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('table panel ends after its rows and keeps full width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppWorkspacePage(
            header: const AppPageHeader(
              title: 'Accounts',
              subtitle: 'Assigned accounts',
            ),
            body: AppTablePanel(
              child: FullWidthDataTable(
                columns: const [DataColumn(label: Text('ACCOUNT'))],
                rows: const [
                  DataRow(cells: [DataCell(Text('Inspection Team'))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final card = find.descendant(
      of: find.byType(AppTablePanel),
      matching: find.byType(AppCard),
    );
    expect(tester.getSize(card).height, lessThan(200));
    expect(tester.getSize(card).width, 800);
    expect(tester.takeException(), isNull);
  });
  testWidgets('short workspace keeps header tools and results reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppWorkspacePage(
            header: const AppPageHeader(
              title: 'Reports & Analytics',
              subtitle: 'Review plants and inspections',
            ),
            tools: const AppToolbarCard(
              child: TextField(
                decoration: InputDecoration(labelText: 'Search'),
              ),
            ),
            body: AppEmptyState(
              title: 'No records',
              message: 'Choose another view.',
              action: FilledButton(
                onPressed: () => tapped = true,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
  test('list workspaces adopt the same page component', () {
    for (final path in [
      'lib/screens/plants/plant_list_screen.dart',
      'lib/screens/qr/qr_management_screen.dart',
      'lib/screens/admin/activity_log_screen.dart',
      'lib/screens/admin/reports/plant_report_screen.dart',
      'lib/screens/admin/inspection_accounts_screen.dart',
      'lib/screens/super_admin/manage_accounts_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('AppWorkspacePage('),
        reason: path,
      );
    }
  });
}
