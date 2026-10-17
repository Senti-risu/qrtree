import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/health_status_label.dart';

void main() {
  test('health labels normalize presentation without changing enum values', () {
    const cases = {
      'Alive': 'Healthy',
      ' healthy ': 'Healthy',
      'Dying': 'Needs attention',
      'At Risk': 'Needs attention',
      'Needs attention': 'Needs attention',
      'Dead': 'Dead',
      'deceased': 'Dead',
      '': 'Unknown',
      'seedling': 'seedling',
    };
    for (final entry in cases.entries) {
      expect(healthStatusLabel(entry.key), entry.value);
    }
    expect(healthStatusLabel(null), 'Unknown');
  });
}
