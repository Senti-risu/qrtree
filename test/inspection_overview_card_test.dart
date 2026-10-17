import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/inspection_overview_card.dart';
import 'package:flutter_application_1/screens/admin/dashboard widgets/dashboard_priority_layout.dart';

void main() {
  for (final width in [320.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('overview fills actual dashboard column at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final contentWidth = width - 32;
        final sideBySide = contentWidth >= 720 && scale < 1.6;
        final cardWidth = sideBySide ? (contentWidth - 16) / 2 : contentWidth;
        var overdue = false;
        var due = false;
        var scan = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1200),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DashboardPriorityLayout(
                    work: InspectionOverviewCard(
                      key: const Key('overview'),
                      availableWidth: cardWidth,
                      metrics: [
                        InspectionOverviewMetric(
                          label: 'Overdue',
                          count: 0,
                          icon: Icons.schedule,
                          onPressed: () => overdue = true,
                        ),
                        InspectionOverviewMetric(
                          label: 'Due today',
                          count: 0,
                          icon: Icons.today,
                          onPressed: () => due = true,
                        ),
                      ],
                      lastInspection:
                          'Last inspection: Thursday, October 15, 2026',
                      message:
                          'No inspections due. Scan a tag to review plant health.',
                      actions: [
                        OutlinedButton(
                          key: const Key('review'),
                          onPressed: () {},
                          child: const Text('Review plants'),
                        ),
                        FilledButton(
                          key: const Key('scan'),
                          onPressed: () => scan = true,
                          child: const Text('Scan QR'),
                        ),
                      ],
                    ),
                    recent: const AppCard(
                      key: Key('chart'),
                      child: SizedBox(
                        height: 260,
                        child: Text('Plant Health Overview'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final card = tester.getRect(find.byKey(const Key('overview')));
        final innerWidth = cardWidth - 34;
        final overdueFinder = find.widgetWithText(OutlinedButton, 'Overdue');
        final dueFinder = find.widgetWithText(OutlinedButton, 'Due today');
        final overdueRect = tester.getRect(overdueFinder);
        final dueRect = tester.getRect(dueFinder);
        final reviewRect = tester.getRect(find.byKey(const Key('review')));
        final scanRect = tester.getRect(find.byKey(const Key('scan')));
        final lastRect = tester.getRect(
          find.byKey(const ValueKey('last-inspection-row')),
        );
        expect(lastRect.width, closeTo(innerWidth, .01));
        expect(lastRect.left, closeTo(card.left + 17, .01));
        if (innerWidth >= 300 && scale < 1.4) {
          expect(dueRect.top, overdueRect.top);
          expect(dueRect.right, closeTo(card.right - 17, .01));
          expect(scanRect.top, reviewRect.top);
          expect(scanRect.right, closeTo(card.right - 17, .01));
          expect(reviewRect.width, closeTo((innerWidth - 8) / 2, .01));
        } else {
          expect(overdueRect.width, closeTo(innerWidth, .01));
          expect(scanRect.width, closeTo(innerWidth, .01));
          expect(dueRect.top, greaterThan(overdueRect.bottom));
        }
        await tester.tap(overdueFinder);
        await tester.tap(dueFinder);
        await tester.tap(find.byKey(const Key('scan')));
        expect(overdue && due && scan, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('render overview width-fill preview', (tester) async {
    tester.view.physicalSize = const Size(1000, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('preview'),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: DashboardPriorityLayout(
                  work: InspectionOverviewCard(
                    availableWidth: 476,
                    metrics: [
                      InspectionOverviewMetric(
                        label: 'Overdue',
                        count: 0,
                        icon: Icons.schedule,
                        onPressed: () {},
                      ),
                      InspectionOverviewMetric(
                        label: 'Due today',
                        count: 0,
                        icon: Icons.today,
                        onPressed: () {},
                      ),
                    ],
                    lastInspection:
                        'Last inspection: Thursday, October 15, 2026',
                    message:
                        'No inspections due. Scan a tag to review plant health.',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Review plants'),
                      ),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR'),
                      ),
                    ],
                  ),
                  recent: const AppCard(
                    child: SizedBox(
                      height: 260,
                      child: Center(child: Text('Health chart panel')),
                    ),
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
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/layout_previews').createSync(recursive: true);
      File(
        'build/layout_previews/inspection-overview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
