import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class ActivityLogService {
  ActivityLogService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> list({
    String? action,
    String? entityType,
    int limit = 100,
    int offset = 0,
  }) async {
    final data = await _client.rpc(
      'list_activity_log',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_action': _emptyToNull(action),
        'p_entity_type': _emptyToNull(entityType),
        'p_limit': limit.clamp(1, 200),
        'p_offset': offset < 0 ? 0 : offset,
      },
    );

    return List<Map<String, dynamic>>.from(data as List);
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
