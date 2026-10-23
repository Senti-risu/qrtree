import 'plant_record_lock.dart';

class InspectionSchedule {
  static const defaultIntervalDays = 7;

  static int intervalDays(Map<String, dynamic> plant) {
    final value = int.tryParse('${plant['inspection_interval_days'] ?? ''}');
    return value != null && value >= 1 && value <= 3650
        ? value
        : defaultIntervalDays;
  }

  static DateTime? _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static bool isOverdue(
    Map<String, dynamic> plant, {
    DateTime? lastInspected,
    DateTime? now,
  }) {
    if (PlantRecordLock.isDead(plant) || plant['archived_at'] != null) {
      return false;
    }
    final reference =
        _date(plant['last_inspected_on']) ??
        _date(lastInspected) ??
        _date(plant['date_planted']) ??
        _date(plant['created_at']);
    final due =
        _date(plant['next_inspection_due_on']) ??
        reference?.add(Duration(days: intervalDays(plant)));
    final today = _date(now ?? DateTime.now())!;
    return due != null && due.isBefore(today);
  }
}
