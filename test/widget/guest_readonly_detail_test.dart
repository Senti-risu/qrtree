import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/public/guest_plant_detail_screen.dart';
import 'package:flutter_application_1/services/guest_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('guest plant details are responsive and view-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const plant = GuestPlantProfile(
      plantId: 42,
      qrCode: 'ECOTAG-202610-000001',
      commonName: 'Narra',
      scientificName: 'Pterocarpus indicus',
      plantType: 'Tree',
      variety: 'Native',
      datePlanted: '2026-10-14',
      campusName: 'CSU Lasam',
      collegeName: 'College of Information and Computing Sciences',
      growthStage: 'Mature',
      healthStatus: 'Healthy',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: GuestPlantDetailScreen(plant: plant),
        ),
      ),
    );

    expect(
      find.text('Guest view · This plant profile is read-only.'),
      findsOneWidget,
    );
    expect(find.text('Narra'), findsOneWidget);
    expect(find.text('Pterocarpus indicus'), findsOneWidget);
    expect(find.text('ECOTAG-202610-000001'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Inspect'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
