import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class InspectionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getPlant(int plantId) async {
    final row = await _supabase
        .from('plant')
        .select('''
      plant_id, variety, date_planted, tree_planter, photo_url, created_at,
      campus_id, college_id, growth_status_id, health_status_id,
      last_inspected_on, next_inspection_due_on, inspection_interval_days,
      archived_at, archive_reason,
      plant_classification (common_name, scientific_name, plant_type),
      campus (campus_name), college (college_name),
      town (town_name), barangay (barangay_name),
      growth_status (growth_stage), health_status (status_name)
    ''')
        .eq('plant_id', plantId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> getInspections(int plantId) async {
    final rows = await _supabase
        .from('inspection')
        .select('''
      *,
      growth_status (growth_stage), health_status (status_name),
      users (username)
    ''')
        .eq('plant_id', plantId)
        .order('inspected_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Returns the role-scoped plant inspection queue.
  ///
  /// Scope checks and date filtering are performed by the database function so
  /// the app never needs to download another campus or college's queue.
  Future<List<Map<String, dynamic>>> listInspectionQueue({
    String filter = 'action',
    DateTime? completedSince,
  }) async {
    const allowedFilters = {
      'action',
      'due_today',
      'overdue',
      'upcoming',
      'completed',
      'all',
    };
    if (!allowedFilters.contains(filter)) {
      throw ArgumentError.value(filter, 'filter', 'Unsupported queue filter');
    }

    final data = await _supabase.rpc(
      'list_inspection_queue',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_filter': filter,
        'p_completed_since': _dateOnly(
          completedSince ?? DateTime.now().subtract(const Duration(days: 30)),
        ),
      },
    );
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Updates the recurring inspection schedule for a plant in the current
  /// College Admin's scope.
  Future<void> updateInspectionSchedule({
    required int plantId,
    required DateTime nextDueOn,
    required int intervalDays,
  }) async {
    if (intervalDays < 1 || intervalDays > 3650) {
      throw ArgumentError.value(
        intervalDays,
        'intervalDays',
        'Inspection interval must be between 1 and 3650 days',
      );
    }
    await _supabase.rpc(
      'college_admin_update_inspection_schedule',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_next_due_on': _dateOnly(nextDueOn),
        'p_interval_days': intervalDays,
      },
    );
  }

  Future<String> uploadInspectionPhoto({
    required int plantId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path =
        'plant-$plantId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from('plant-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    return _supabase.storage.from('plant-images').getPublicUrl(path);
  }

  Future<void> saveInspection({
    required int plantId,
    required int inspectedBy,
    required int healthStatusId,
    required int growthStatusId,
    required String observation,
    String? photoUrl,
  }) async {
    await _supabase.rpc(
      'inspection_team_submit_inspection',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_health_status_id': healthStatusId,
        'p_growth_status_id': growthStatusId,
        'p_observation': observation.trim().isEmpty ? null : observation.trim(),
        'p_photo_url': photoUrl,
      },
    );
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
