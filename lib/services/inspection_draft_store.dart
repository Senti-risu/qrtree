import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Each draft is stored separately so concurrent saves cannot overwrite a queue.
class InspectionDraftStore {
  InspectionDraftStore({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  String _prefix(int userId) => 'ecotag_inspection_v1_${userId}_';

  static String newId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> save(int userId, Map<String, dynamic> draft) => storage.write(
    key: '${_prefix(userId)}${draft['id']}',
    value: jsonEncode(draft),
  );

  Future<List<Map<String, dynamic>>> list(int userId) async {
    final values = await storage.readAll();
    return values.entries
        .where((e) => e.key.startsWith(_prefix(userId)))
        .map((e) => Map<String, dynamic>.from(jsonDecode(e.value) as Map))
        .toList()
      ..sort((a, b) => '${a['observedAt']}'.compareTo('${b['observedAt']}'));
  }

  Future<void> remove(int userId, String id) =>
      storage.delete(key: '${_prefix(userId)}$id');

  Future<void> cacheOptions(int userId, List<dynamic> options) => storage.write(
    key: 'ecotag_inspection_options_$userId',
    value: jsonEncode(options),
  );

  Future<void> cachePlants(int userId, List<Map<String, dynamic>> plants) =>
      storage.write(
        key: 'ecotag_inspection_plants_$userId',
        value: jsonEncode(plants),
      );

  Future<List<Map<String, dynamic>>> plants(int userId) async {
    final raw = await storage.read(key: 'ecotag_inspection_plants_$userId');
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
  }

  Future<Map<String, dynamic>?> plantForQrCode(int userId, String code) async {
    final normalizedCode = code.trim().toLowerCase();
    if (normalizedCode.isEmpty) return null;
    for (final plant in await plants(userId)) {
      final qrTag = plant['qr_tag'];
      final qrCode = qrTag is Map
          ? qrTag['qr_code_string']?.toString().trim().toLowerCase()
          : null;
      final qrTagId = plant['qr_tag_id']?.toString().trim().toLowerCase();
      if (qrCode == normalizedCode || qrTagId == normalizedCode) return plant;
    }
    return null;
  }

  Future<List<List<Map<String, dynamic>>>?> options(int userId) async {
    final raw = await storage.read(key: 'ecotag_inspection_options_$userId');
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .map(
          (items) => (items as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
        )
        .toList();
  }
}
