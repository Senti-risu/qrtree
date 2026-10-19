import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/inspection_queue_layout.dart';

Widget queuePage({
  required VoidCallback onNext,
  required ValueChanged<String> onFilter,
}) => InspectionQueueLayout(
  header: const AppPageHeader(
    key: Key('header'),
    title: 'Inspections',
    subtitle: 'Prioritize scheduled work and review completed inspections',
  ),
  filters: InspectionQueueFilters(
    key: const Key('filters'),
    selected: 'action',
    onSelected: onFilter,
  ),
  body: InspectionQueueEmptyState(filter: 'action', onNext: onNext),
);

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(600, 300),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('inspection sections align at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var next = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: queuePage(onNext: () => next = true, onFilter: (_) {}),
                ),
              ),
            ),
          ),
        );
        final header = tester.getRect(find.byKey(const Key('header')));
        final filters = tester.getRect(find.byKey(const Key('filters')));
        expect(header.left, filters.left);
        expect(header.width, filters.width);
        final combined = tester.getRect(
          find.byKey(const ValueKey('workspace-heading-filters')),
        );
        expect(combined.width, size.width - 32);
        expect(combined.contains(header.topLeft), isTrue);
        expect(combined.contains(filters.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
        final action = find.text('View upcoming');
        await tester.ensureVisible(action);
        await tester.tap(action);
        expect(next, isTrue);
        expect(tester.takeException(), isNull);
        if (size.width == 1440 && scale == 1) {
          final emptyCard = find.descendant(
            of: find.byType(InspectionQueueEmptyState),
            matching: find.byType(Column),
          );
          expect(tester.getSize(emptyCard).height, lessThan(280));
        }
      });
    }
  }
  testWidgets('every mobile filter remains reachable and pressable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: InspectionQueueFilters(
            selected: 'action',
            onSelected: (v) => selected = v,
          ),
        ),
      ),
    );
    for (final entry in InspectionQueueFilters.filters.entries) {
      await tester.ensureVisible(find.text(entry.value));
      await tester.tap(find.text(entry.value));
      expect(selected, entry.key);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('render aligned inspection queue preview', (tester) async {
    tester.view.physicalSize = const Size(1000, 650);
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
              padding: const EdgeInsets.all(20),
              child: queuePage(onNext: () {}, onFilter: (_) {}),
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
        'build/layout_previews/inspection-queue.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
