import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One device-local draft per account, assignment and QR registration context.
/// Ownership is part of the storage key and is never restored from draft data.
class RegistrationDraftStore {
  RegistrationDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyFor({
    required int userId,
    required String role,
    int? campusId,
    int? collegeId,
    int? qrTagId,
  }) =>
      'ecotag_registration_v1_${userId}_${Uri.encodeComponent(role)}_'
      '${campusId ?? 0}_${collegeId ?? 0}_${qrTagId ?? 0}';

  Future<Map<String, dynamic>?> read(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported registration draft');
    }
    if (decoded['completed'] == true) return null;
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration draft');
    }
    return data;
  }

  Future<void> save(String key, Map<String, dynamic> data) =>
      _storage.write(key: key, value: jsonEncode({'version': 1, 'data': data}));

  Future<void> discard(String key) => _storage.delete(key: key);

  Future<void> complete(String key) async {
    // A tiny tombstone prevents a stale draft being offered if deletion fails.
    try {
      await _storage.write(
        key: key,
        value: jsonEncode({'version': 1, 'completed': true}),
      );
    } catch (_) {
      await discard(key);
      return;
    }
    try {
      await discard(key);
    } catch (_) {
      // The completed marker is sufficient; cleanup can wait.
    }
  }
}
