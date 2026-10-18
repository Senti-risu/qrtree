import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'redundant form hints are removed but privacy and critical warnings remain',
    () {
      final registration = File(
        'lib/screens/admin/registration/register_plant_screen.dart',
      ).readAsStringSync();
      final inspection = File(
        'lib/screens/inspections/inspection_form_screen.dart',
      ).readAsStringSync();
      final editor = File(
        'lib/widgets/plant_details_editor.dart',
      ).readAsStringSync();
      expect(
        registration,
        isNot(contains('Check the required fields before registering.')),
      );
      expect(
        inspection,
        isNot(contains('Recommended for tracking visible changes')),
      );
      expect(inspection, isNot(contains('Choose what you observe today')));
      expect(
        inspection,
        isNot(contains('Keep the existing stage or select a new one.')),
      );
      expect(editor, isNot(contains('Based on the selected common name.')));
      expect(
        inspection,
        contains('Avoid entering private personal information.'),
      );
      expect(
        File('lib/screens/public/guest_entry_screen.dart').readAsStringSync(),
        contains('Privacy: only your age is recorded'),
      );
      expect(
        File('lib/widgets/dead_plant_lock.dart').readAsStringSync(),
        contains('Saving Dead will lock routine edits'),
      );
    },
  );

  test(
    'guest access retains one full read-only explanation and privacy details',
    () {
      final guest = File(
        'lib/screens/public/guest_dashboard_screen.dart',
      ).readAsStringSync();
      expect(
        guest,
        contains(
          'Guests cannot register, edit, inspect, archive, or manage plants.',
        ),
      );
      expect(
        guest,
        isNot(
          contains(
            'Guest access is read-only. Plant management and inspection tools',
          ),
        ),
      );
      expect(
        guest,
        contains(
          'Only your age was recorded for anonymous visitor statistics.',
        ),
      );
    },
  );
}
