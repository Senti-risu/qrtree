import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/inspection_reminders.dart';

void main() {
  Map<String, dynamic> plant(int id, String due) => {
    'plant_id': id,
    'next_inspection_due_on': due,
  };
  test('summaries include overdue and upcoming plants when due', () {
    final plan = planInspectionReminders(
      [plant(1, '2026-10-20'), plant(2, '2026-10-22'), plant(1, '2026-10-20')],
      DateTime(2026, 10, 21, 7),
      8,
      0,
    );
    expect(plan.length, 30);
    expect(plan.first.at, DateTime(2026, 10, 21, 8));
    expect(plan.first.count, 1);
    expect(plan[1].count, 2);
  });
  test('completed, Dead, archived, and unscheduled plants are excluded', () {
    final plan = planInspectionReminders(
      [
        {...plant(1, '2026-10-21'), 'last_inspected_on': '2026-10-21'},
        {
          ...plant(2, '2026-10-21'),
          'health_status': {'status_name': 'Dead'},
        },
        {...plant(3, '2026-10-21'), 'archived_at': '2026-10-20'},
        {'plant_id': 4},
      ],
      DateTime(2026, 10, 21),
      8,
      0,
    );
    expect(plan, isEmpty);
  });
  test('passed reminder time skips today and date rollover works', () {
    final plan = planInspectionReminders(
      [plant(1, '2026-12-31')],
      DateTime(2026, 12, 31, 9),
      8,
      0,
    );
    expect(plan.first.at, DateTime(2027, 1, 1, 8));
    expect(plan.length, 29);
  });
}
