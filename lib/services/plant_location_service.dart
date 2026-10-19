import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_session.dart';

class PlantLocationService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> get(int plantId) async {
    final data = await _client.rpc(
      'get_plant_physical_location',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> update(
    int plantId,
    String choice,
    int townId,
    int barangayId,
  ) async {
    await _client.rpc(
      'update_plant_physical_location',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_location_type': choice == 'outside' ? 'outside' : 'inside',
        'p_location_campus_id': choice == 'outside' ? null : int.parse(choice),
        'p_town_id': townId,
        'p_barangay_id': barangayId,
      },
    );
  }

  static String label(Map<String, dynamic> data) =>
      switch (data['planting_location_type']) {
        'outside' => 'Outside Campus',
        'inside' =>
          data['planting_campus_name']?.toString() ?? 'Campus not available',
        _ => 'Not Recorded Yet',
      };
}
