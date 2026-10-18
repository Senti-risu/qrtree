import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/forms/planting_campus_dropdown.dart';
import 'package:flutter_application_1/services/plant_location_service.dart';
import 'package:flutter_application_1/services/guest_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  test('outside planting location does not replace managing campus', () {
    final profile = GuestPlantProfile.fromJson({
      'plant_id': 1,
      'qr_code': 'ECOTAG-202610-1',
      'common_name': 'Mango',
      'campus_name': 'CSU Lasam',
      'college_name': 'CICS',
      'planting_location_type': 'outside',
      'town_name': 'Tuguegarao',
    });
    expect(profile.campusName, 'CSU Lasam');
    expect(profile.townName, 'Tuguegarao');
    expect(profile.plantingLocationLabel, 'Outside campus');
    expect(PlantingCampusDropdown.campusId('outside'), isNull);
  });

  test('older records do not infer a physical location from ownership', () {
    expect(PlantLocationService.label({'campus_id': 1}), 'Not recorded yet');
    expect(
      PlantLocationService.label({
        'planting_location_type': 'inside',
        'planting_campus_name': 'CSU Tuguegarao',
      }),
      'CSU Tuguegarao',
    );
  });

  testWidgets(
    'planting selector is unlocked on narrow phones and requires an explicit choice',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? choice;
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, update) => Form(
                  key: form,
                  child: Column(
                    children: [
                      const Text('Managing campus: CSU Lasam'),
                      PlantingCampusDropdown(
                        campuses: const [
                          {'campus_id': 1, 'campus_name': 'CSU Lasam'},
                          {'campus_id': 2, 'campus_name': 'CSU Tuguegarao'},
                        ],
                        value: choice,
                        onChanged: (value) => update(() => choice = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outside campus').last);
      await tester.pumpAndSettle();
      expect(choice, 'outside');
      expect(form.currentState!.validate(), isTrue);
      expect(find.text('Managing campus: CSU Lasam'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSU Tuguegarao').last);
      await tester.pumpAndSettle();
      expect(PlantingCampusDropdown.campusId(choice), 2);
      expect(find.text('Managing campus: CSU Lasam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
