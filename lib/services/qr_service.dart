import '../utils/search_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class QrService {
  QrService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Returns the lifecycle name used by the current app. Older databases used
  /// `lost`; those rows are treated as retired so the UI has one clear terminal
  /// state while the production migration is being rolled out.
  static String normalizedStatus(Object? value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return switch (status) {
      'available' => 'available',
      'assigned' => 'assigned',
      'damaged' => 'damaged',
      'replaced' => 'replaced',
      'lost' || 'retired' => 'retired',
      _ => 'unknown',
    };
  }

  static String statusOf(Map<String, dynamic> tag) =>
      normalizedStatus(tag['lifecycle_status'] ?? tag['status']);

  Future<Map<String, dynamic>> createQrTag() async {
    final rows = await createQrTags(1);
    return rows.single;
  }

  Future<List<Map<String, dynamic>>> createQrTags(int amount) async {
    if (amount < 1 || amount > 500) {
      throw Exception('Amount must be between 1 and 500.');
    }
    final data =
        await _supabase.rpc(
              'college_admin_create_qr_tags',
              params: {
                'p_session_token': AppSession.requiredToken,
                'p_amount': amount,
              },
            )
            as List;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> findQrTag(String code) async {
    final value = code.trim();
    if (value.isEmpty) return null;
    final numericId = int.tryParse(value);
    Map<String, dynamic>? data;
    try {
      final query = _supabase.from('qr_tag').select('''
            qr_tag_id, qr_code_string, status, lifecycle_status, created_at,
            replacement_qr_tag_id, status_reason
          ''');
      data = numericId == null
          ? await query.eq('qr_code_string', value).maybeSingle()
          : await query.eq('qr_tag_id', numericId).maybeSingle();
    } on PostgrestException catch (error) {
      if (!_isMissingLifecycleColumn(error)) rethrow;
      final query = _supabase
          .from('qr_tag')
          .select('qr_tag_id, qr_code_string, status, created_at');
      data = numericId == null
          ? await query.eq('qr_code_string', value).maybeSingle()
          : await query.eq('qr_tag_id', numericId).maybeSingle();
    }
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<int?> getAssignedPlantId(int qrTagId) async {
    final plant = await _supabase
        .from('plant')
        .select('plant_id')
        .eq('qr_tag_id', qrTagId)
        .isFilter('archived_at', null)
        .maybeSingle();
    return plant?['plant_id'] as int?;
  }

  Future<List<Map<String, dynamic>>> getTags({
    String? status,
    String? search,
    int limit = 500,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be from 1 to 500.');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Offset cannot be negative.');
    }

    final normalizedFilter = status == null ? null : normalizedStatus(status);
    try {
      final data = await _supabase.rpc(
        'college_admin_list_qr_tags',
        params: {
          'p_session_token': AppSession.requiredToken,
          'p_status': normalizedFilter == 'unknown' ? null : normalizedFilter,
          'p_search': _emptyToNull(search),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return List<Map<String, dynamic>>.from(data as List);
    } on PostgrestException catch (error) {
      // During a staged rollout only a missing RPC falls back to the legacy
      // read. Authorization, session, and database errors must remain visible.
      if (!_isMissingFunction(error)) rethrow;
      return _legacyTags(
        status: normalizedFilter,
        search: search,
        limit: limit,
        offset: offset,
      );
    }
  }

  Future<void> markDamaged({required int qrTagId, required String reason}) =>
      _lifecycleAction(
        rpc: 'college_admin_mark_qr_damaged',
        params: {'p_qr_tag_id': qrTagId, 'p_reason': _requiredReason(reason)},
      );

  Future<void> confirmReprinted({required int qrTagId}) => _lifecycleAction(
    rpc: 'college_admin_confirm_qr_reprinted',
    params: {'p_qr_tag_id': qrTagId},
  );

  Future<void> retireTag({required int qrTagId, required String reason}) =>
      _lifecycleAction(
        rpc: 'college_admin_retire_qr',
        params: {'p_qr_tag_id': qrTagId, 'p_reason': _requiredReason(reason)},
      );

  Future<void> replaceTag({
    required int oldQrTagId,
    required int replacementQrTagId,
    required String reason,
  }) => _lifecycleAction(
    rpc: 'college_admin_replace_qr',
    params: {
      'p_old_qr_tag_id': oldQrTagId,
      'p_replacement_qr_tag_id': replacementQrTagId,
      'p_reason': _requiredReason(reason),
    },
  );

  Future<void> _lifecycleAction({
    required String rpc,
    required Map<String, dynamic> params,
  }) async {
    await _supabase.rpc(
      rpc,
      params: {'p_session_token': AppSession.requiredToken, ...params},
    );
  }

  Future<List<Map<String, dynamic>>> _legacyTags({
    required String? status,
    required String? search,
    required int limit,
    required int offset,
  }) async {
    final data = await _supabase
        .from('qr_tag')
        .select('qr_tag_id, qr_code_string, status, created_at')
        .order('qr_tag_id', ascending: false)
        .limit(500);
    final term = search?.trim().toLowerCase() ?? '';
    final rows = List<Map<String, dynamic>>.from(data).where((tag) {
      final tagStatus = statusOf(tag);
      if (status != null && status != 'unknown' && tagStatus != status) {
        return false;
      }
      if (term.isEmpty) return true;
      return matchesWordPrefixes([
        tag['qr_code_string'],
        tag['qr_tag_id'],
        tagStatus,
      ], term);
    }).toList();
    if (offset >= rows.length) return const [];
    final end = (offset + limit).clamp(0, rows.length);
    return rows.sublist(offset, end);
  }

  String _requiredReason(String value) {
    final normalized = value.trim();
    if (normalized.length < 3 || normalized.length > 250) {
      throw ArgumentError.value(
        value,
        'reason',
        'Provide a reason from 3 to 250 characters.',
      );
    }
    return normalized;
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  bool _isMissingFunction(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42883' ||
        error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('function public.college_admin_list_qr_tags');
  }

  bool _isMissingLifecycleColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        message.contains('lifecycle_status') ||
        message.contains('status_reason');
  }
}
