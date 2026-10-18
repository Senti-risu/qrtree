import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/dashboard_stat_card.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/recent_plants_table.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/equal_height_cards.dart';

void main() {
  for (final width in [320.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('stat cards match at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var tapped = false;
        final columns = width >= 900 ? 4 : 2;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1600),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  child: EqualHeightCards(
                    columns: columns,
                    gap: 12,
                    children: [
                      for (var i = 0; i < 4; i++)
                        DashboardStatCard(
                          key: ValueKey('stat-$i'),
                          title: [
                            'Total Plants',
                            'Healthy Plants',
                            'Needs attention',
                            'Dead Plants',
                          ][i],
                          value: '$i',
                          subtext: i == 1
                              ? '75% of total plants'
                              : 'In assigned college',
                          icon: Icons.eco,
                          iconBgColor: Colors.green.shade50,
                          iconColor: Colors.green,
                          compact: width < 600,
                          progress: i == 1 ? 0.75 : null,
                          onTap: () => tapped = true,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final sizes = [
          for (var i = 0; i < 4; i++)
            tester.getSize(find.byKey(ValueKey('stat-$i'))),
        ];
        for (final size in sizes) {
          expect(size, sizes.first);
        }
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('stat-1'))).dx,
          closeTo(sizes.first.width + 12, 0.1),
        );
        await tester.tap(find.byKey(const ValueKey('stat-0')));
        expect(tapped, isTrue);
      });
    }
  }

  testWidgets('supports real recent plants LayoutBuilder and updates columns', (
    tester,
  ) async {
    Future<void> pump(int columns) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EqualHeightCards(
                columns: columns,
                children: [
                  const AppCard(
                    key: Key('actions'),
                    child: SizedBox(height: 350, child: Text('Quick Actions')),
                  ),
                  AppCard(
                    key: const Key('recent'),
                    child: RecentPlantsTable(
                      plants: const [],
                      onViewAll: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await pump(2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('actions'))),
      tester.getSize(find.byKey(const Key('recent'))),
    );
    await pump(1);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('recent'))).dy,
      greaterThan(tester.getBottomLeft(find.byKey(const Key('actions'))).dy),
    );
    expect(tester.getSize(find.byKey(const Key('actions'))).width, 800);
  });
}
