import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/plant_detail_content.dart';
import 'package:flutter_application_1/widgets/plant_ecotag_header.dart';

Widget content(VoidCallback onInspect) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const PlantEcoTagHeader(code: 'ECOTAG-202610-000003'),
    const PlantDetailHero(
      name: 'Cacao',
      scientificName: 'Theobroma cacao',
      plantId: '6',
      imageUrl: '',
    ),
    PlantDetailSectionPair(
      first: const PlantDetailFields(
        key: Key('status'),
        title: 'Status',
        rows: {'Health Status': 'Healthy', 'Growth Stage': 'Mature'},
      ),
      second: PlantDetailFields(
        key: const Key('schedule'),
        title: 'Inspection Schedule',
        trailing: IconButton(
          tooltip: 'Edit schedule',
          onPressed: () {},
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
        badge: const Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('Upcoming')),
        ),
        rows: const {
          'Last Inspected': 'Not Inspected',
          'Next Inspection': 'Oct 22, 2026',
          'Schedule Repeats': 'Every 7 Days',
        },
      ),
    ),
    const PlantDetailSectionPair(
      first: PlantDetailFields(
        key: Key('managed'),
        title: 'Managed By',
        rows: {
          'Managing Campus': 'CSU Lasam',
          'Managing College': 'College of Information and Computing Sciences',
        },
      ),
      second: PlantDetailFields(
        key: Key('location'),
        title: 'Planting Location',
        rows: {
          'Campus / outside': 'Outside Campus',
          'Barangay': 'Centro 2',
          'Town': 'Lasam',
        },
      ),
    ),
    PlantDetailActions(
      children: [
        FilledButton.icon(
          onPressed: onInspect,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Inspect Plant'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Update planting location'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.warning_amber),
          label: const Text('Report QR Problem'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history),
          label: const Text('Review QR reports'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive Plant'),
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('phone-style actions remain stacked on wide web screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PlantDetailActions(
            singleColumn: true,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Inspect')),
              OutlinedButton(onPressed: () {}, child: const Text('Report')),
            ],
          ),
        ),
      ),
    );
    final inspect = tester.getRect(find.byType(FilledButton));
    final report = tester.getRect(find.byType(OutlinedButton));
    expect(report.left, inspect.left);
    expect(report.width, inspect.width);
    expect(report.top, greaterThan(inspect.bottom));
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 600.0, 1080.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('plant detail design fits $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var inspected = false;
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
                  child: content(() => inspected = true),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        if (width >= 752 && scale < 1.6) {
          for (final pair in [
            ('status', 'schedule'),
            ('managed', 'location'),
          ]) {
            final first = tester.getRect(find.byKey(Key(pair.$1)));
            final second = tester.getRect(find.byKey(Key(pair.$2)));
            expect(first.size, second.size);
            expect(first.top, second.top);
            expect(first.bottom, second.bottom);
          }
        }
        await tester.ensureVisible(find.text('Inspect Plant'));
        await tester.tap(find.text('Inspect Plant'));
        expect(inspected, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('render compact desktop plant details preview', (tester) async {
    tester.view.physicalSize = const Size(1080, 1200);
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
            appBar: AppBar(
              title: const Text('Plant Details'),
              leading: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.close),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: content(() {}),
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
        'build/layout_previews/plant-detail-design.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
