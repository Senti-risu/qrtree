import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_account.dart';
import 'app_session.dart';

class SuperAdminService {
  SuperAdminService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminAccount>> getAccounts(int actorUserId) async {
    final rows =
        await _client.rpc(
              'super_admin_list_users',
              params: {'p_session_token': AppSession.requiredToken},
            )
            as List;
    return rows
        .map((row) => AdminAccount.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminAccount>> getArchivedAccounts() async {
    final rows =
        await _client.rpc(
              'super_admin_list_archived_users',
              params: {'p_session_token': AppSession.requiredToken},
            )
            as List;
    return rows
        .map((row) => AdminAccount.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminScopeOption>> getCampuses() async {
    final rows =
        await _client
                .from('campus')
                .select('campus_id,campus_name')
                .order('campus_name')
            as List;
    return rows
        .map(
          (row) => AdminScopeOption(
            id: row['campus_id'] as int,
            name: row['campus_name'].toString(),
          ),
        )
        .toList();
  }

  Future<List<AdminScopeOption>> getColleges(int campusId) async {
    final rows =
        await _client
                .from('college')
                .select('college_id,college_name,campus_id')
                .eq('campus_id', campusId)
                .order('college_name')
            as List;
    return rows
        .map(
          (row) => AdminScopeOption(
            id: row['college_id'] as int,
            name: row['college_name'].toString(),
            campusId: row['campus_id'] as int,
          ),
        )
        .toList();
  }

  Future<void> createAccount({
    required int actorUserId,
    required String username,
    required String password,
    required String role,
    int? campusId,
    int? collegeId,
  }) async {
    await _client.rpc(
      'super_admin_create_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_username': username.trim(),
        'p_password': password,
        'p_role': role,
        'p_campus_id': campusId,
        'p_college_id': collegeId,
      },
    );
  }

  Future<void> setAccountActive({
    required int actorUserId,
    required int targetUserId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'super_admin_set_user_active',
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
    required String role,
    int? campusId,
    int? collegeId,
    String? newPassword,
  }) async {
    await _client.rpc(
      'super_admin_update_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
        'p_username': username.trim(),
        'p_role': role,
        'p_campus_id': campusId,
        'p_college_id': collegeId,
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
      'super_admin_archive_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> restoreAccount(int targetUserId) async {
    await _client.rpc(
      'super_admin_restore_user',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_target_user_id': targetUserId,
      },
    );
  }
}
