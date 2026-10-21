import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/plant_summary_card.dart';

void main() {
  for (final testCase in [
    (role: 'college_admin', managementLabel: null, managementValue: null),
    (
      role: 'campus_admin',
      managementLabel: 'Managed By College',
      managementValue: 'College of Science',
    ),
    (
      role: 'university_admin',
      managementLabel: 'Managed By Campus',
      managementValue: 'CSU Lasam',
    ),
  ]) {
    testWidgets('${testCase.role} sees only its scoped plant details', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlantSummaryCard(
                role: testCase.role,
                name: 'Mango',
                plantType: 'Fruit Tree',
                scientificName: 'Mangifera indica',
                plantedAt: 'Outside Campus, Centro, Lasam',
                college: 'College of Science',
                campus: 'CSU Lasam',
                photo: const Icon(Icons.eco, size: 44),
                status: const Chip(label: Text('Healthy')),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Fruit Tree'), findsOneWidget);
      expect(find.text('Mango'), findsOneWidget);
      expect(find.text('Mangifera indica'), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
      expect(
        find.textContaining('Planted At: Outside Campus, Centro, Lasam'),
        findsOneWidget,
      );
      expect(find.textContaining('Last Inspected'), findsNothing);
      if (testCase.managementLabel == null) {
        expect(find.textContaining('Managed By'), findsNothing);
      } else {
        expect(
          find.textContaining(
            '${testCase.managementLabel}: ${testCase.managementValue}',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            testCase.role == 'campus_admin'
                ? 'CSU Lasam'
                : 'College of Science',
          ),
          findsNothing,
        );
      }
      expect(
        tester.getSize(find.byType(PlantSummaryCard)).height,
        lessThan(220),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
