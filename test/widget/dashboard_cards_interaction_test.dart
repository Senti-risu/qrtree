import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/campus_overview_card.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/recent_plants_table.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('campus overview card responds to a tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CampusOverviewCard(
            counts: const {'CSU Lasam': 13},
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSU Campuses'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent plant mobile card opens the selected plant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? selected;
    var viewedAll = false;
    final plant = <String, dynamic>{
      'plant_id': 12,
      'plant_classification': {'common_name': 'Mango'},
      'qr_tag': {'qr_code_string': 'CSU-202610-000012'},
      'health_status': {'status_name': 'alive'},
      'growth_status': {'growth_stage': 'Mature'},
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentPlantsTable(
              plants: [plant],
              onViewAll: () => viewedAll = true,
              onViewPlant: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mango'));
    expect(selected, same(plant));
    await tester.tap(find.text('Recent Plants'));
    expect(viewedAll, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent plant desktop rows are pressable', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? selected;
    final plant = <String, dynamic>{
      'plant_id': 12,
      'plant_classification': {'common_name': 'Mango'},
      'qr_tag': {'qr_code_string': 'CSU-202610-000012'},
      'health_status': {'status_name': 'alive'},
      'growth_status': {'growth_stage': 'Mature'},
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RecentPlantsTable(
            plants: [plant],
            onViewAll: () {},
            onViewPlant: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mango'));
    expect(selected, same(plant));
    expect(tester.takeException(), isNull);
  });
}
