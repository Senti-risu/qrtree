import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class InspectionAccountService {
  InspectionAccountService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listAccounts(int actorUserId) async {
    final rows =
        await _client.rpc(
              'college_admin_list_inspection_users',
              params: {'p_session_token': AppSession.requiredToken},
            )
            as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listArchivedAccounts() async {
    final rows =
        await _client.rpc(
              'college_admin_list_archived_inspection_users',
              params: {'p_session_token': AppSession.requiredToken},
            )
            as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> createAccount({
    required int actorUserId,
    required String username,
    required String password,
  }) async {
    await _client.rpc(
      'college_admin_create_inspection_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_username': username.trim(),
        'p_password': password,
      },
    );
  }

  Future<void> setActive({
    required int actorUserId,
    required int targetUserId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'college_admin_set_inspection_user_active',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
        'p_is_active': isActive,
      },
    );
  }

  Future<void> updateAccount({
    required int targetUserId,
    required String username,
    String? newPassword,
  }) async {
    await _client.rpc(
      'college_admin_update_inspection_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
        'p_username': username.trim(),
        'p_new_password': newPassword?.trim().isEmpty == true
            ? null
            : newPassword,
      },
    );
  }

  Future<void> archiveAccount({
    required int targetUserId,
    required String reason,
  }) async {
    await _client.rpc(
      'college_admin_archive_inspection_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> restoreAccount(int targetUserId) async {
    await _client.rpc(
      'college_admin_restore_inspection_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
      },
    );
  }
}
