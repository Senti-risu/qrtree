import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/recent_plants_table.dart';

const plants = [
  {
    'plant_id': 3,
    'tree_planter': 'Campus Team',
    'variety': 'Native',
    'plant_classification': {'common_name': 'Narra'},
    'qr_tag': {'qr_code_string': 'ECOTAG-202610-000004'},
    'growth_status': {'growth_stage': 'Seedling'},
    'health_status': {'status_name': 'Healthy'},
  },
  {
    'plant_id': 2,
    'tree_planter': 'Russel',
    'variety': 'Muscle',
    'plant_classification': {'common_name': 'Cacao'},
    'qr_tag': {'qr_code_string': 'ECOTAG-202610-000003'},
    'growth_status': {'growth_stage': 'Old'},
    'health_status': {'status_name': 'Alive'},
    'last_inspected_on': '2026-10-19',
  },
  {
    'plant_id': 1,
    'tree_planter': 'Russel Guerrero',
    'variety': 'Local',
    'plant_classification': {'common_name': 'Coconut'},
    'qr_tag': {'qr_code_string': 'ECOTAG-202610-000002'},
    'growth_status': {'growth_stage': 'Mature'},
    'health_status': {'status_name': 'Dead'},
  },
];

void main() {
  test('dashboard no longer renders Quick Actions or the old shortlist', () {
    final source = File(
      'lib/screens/admin/dashboard/dashboard_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('_buildQuickActionsCard')));
    expect(source, isNot(contains('_buildRecentPlantShortlist')));
    expect(source, contains('onViewPlant:'));
    expect(source, contains('last_inspected_on'));
    expect(source, contains('qr_code_string'));
  });
  for (final width in [320.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'recent plants retain details and actions at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int? opened;
          var viewAll = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: SingleChildScrollView(
                    child: RecentPlantsTable(
                      plants: plants,
                      onViewAll: () => viewAll = true,
                      onViewPlant: (p) => opened = p['plant_id'] as int,
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('ECOTAG-202610-000004'), findsOneWidget);
          expect(find.text('Campus Team'), findsNothing);
          expect(find.text('Healthy'), findsNWidgets(2));
          expect(find.text('Dead'), findsOneWidget);
          await tester.ensureVisible(find.text('View Plant').first);
          await tester.tap(find.text('View Plant').first);
          expect(opened, 3);
          await tester.ensureVisible(find.text('View All'));
          await tester.tap(find.text('View All'));
          expect(viewAll, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('render reference-based recent plants preview', (tester) async {
    tester.view.physicalSize = const Size(1440, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in {
      AppTheme.fontFamily: 'assets/fonts/DMSans-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('recent-preview'),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: RecentPlantsTable(
                  plants: plants,
                  onViewAll: () {},
                  onViewPlant: (_) {},
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
      find.byKey(const Key('recent-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/layout_previews').createSync(recursive: true);
      File(
        'build/layout_previews/recent-plants.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
