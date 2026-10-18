import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/dashboard_priority_layout.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/forms/locked_plant_assignment.dart';
import 'package:flutter_application_1/widgets/forms/planting_campus_dropdown.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('inspection actions occupy the card height alongside the chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardPriorityLayout(
              work: AppCard(
                key: const Key('inspection-card'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inspection overview'),
                    const Text('No inspections due'),
                    FilledButton(
                      key: const Key('scan-action'),
                      onPressed: () {},
                      child: const Text('Scan QR'),
                    ),
                  ],
                ),
              ),
              recent: const AppCard(
                child: SizedBox(height: 260, child: Text('Health chart')),
              ),
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byKey(const Key('inspection-card')));
    final action = tester.getRect(find.byKey(const Key('scan-action')));
    expect(card.bottom - action.bottom, closeTo(16, 1));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('priority cards fill and align at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: DashboardPriorityLayout(
                  work: AppCard(
                    key: const Key('work'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inspection overview'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('Overdue 0'),
                              onPressed: () {},
                            ),
                            ActionChip(
                              label: const Text('Due today 0'),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const Text(
                          'Last inspection: Thursday, October 15, 2026',
                        ),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Review plants'),
                        ),
                      ],
                    ),
                  ),
                  recent: const AppCard(
                    key: Key('recent'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent plants'),
                        ListTile(
                          title: Text('Mango'),
                          subtitle: Text('Plant #1 · Healthy'),
                        ),
                        ListTile(
                          title: Text('Mango'),
                          subtitle: Text('Plant #2 · Healthy'),
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
      final work = tester.getRect(find.byKey(const Key('work')));
      final recent = tester.getRect(find.byKey(const Key('recent')));
      if (width >= 768) {
        expect(work.top, recent.top);
        expect(work.height, recent.height);
        expect(work.width, recent.width);
        expect(recent.right, closeTo(width - 16, .01));
      } else {
        expect(work.width, width - 32);
        expect(recent.width, work.width);
        expect(recent.top, greaterThan(work.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'long locked college name remains readable at large phone text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: LockedPlantAssignment(
                  campus: 'CSU Lasam',
                  college: 'College of Information and Computing Sciences',
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('College of Information and Computing Sciences'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text stacks priority cards and planting label stays visible',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: DashboardPriorityLayout(
                  work: const AppCard(
                    key: Key('work'),
                    child: Text('Inspection overview'),
                  ),
                  recent: AppCard(
                    key: const Key('recent'),
                    child: PlantingCampusDropdown(
                      campuses: const [],
                      value: 'outside',
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('recent'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const Key('work'))).dy),
      );
      expect(find.text('Planting campus'), findsOneWidget);
      expect(find.text('Outside campus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
