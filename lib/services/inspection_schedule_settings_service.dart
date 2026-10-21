import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

abstract interface class InspectionScheduleSettings {
  Future<int> getIntervalDays();
  Future<int> setIntervalDays(int days);
}

class InspectionScheduleSettingsService implements InspectionScheduleSettings {
  InspectionScheduleSettingsService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<int> getIntervalDays() async {
    final result = await _supabase.rpc(
      'university_admin_get_inspection_interval',
      params: {'p_session_token': AppSession.requiredToken},
    );
    if (result is! int || result < 1 || result > 3650) {
      throw StateError('The university inspection interval is invalid.');
    }
    return result;
  }

  @override
  Future<int> setIntervalDays(int days) async {
    if (days < 1 || days > 3650) {
      throw ArgumentError.value(
        days,
        'days',
        'Inspection interval must be from 1 to 3650 days.',
      );
    }
    final result = await _supabase.rpc(
      'university_admin_set_inspection_interval',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_interval_days': days,
      },
    );
    if (result is! int || result != days) {
      throw StateError('The university inspection interval was not updated.');
    }
    return result;
  }
}
