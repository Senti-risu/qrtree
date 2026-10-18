import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_session.dart';
import 'inspection_draft_store.dart';

abstract interface class InspectionUploadBackend {
  Future<void> check(int userId, int plantId);
  Future<String> upload(int plantId, String id, Uint8List bytes);
  Future<void> submit(int userId, Map<String, dynamic> draft);
}

class SupabaseInspectionUploadBackend implements InspectionUploadBackend {
  SupabaseClient get _client => Supabase.instance.client;
  @override
  Future<void> check(int userId, int plantId) async {
    await _client
        .rpc(
          'check_inspection_draft',
          params: {
            'p_session_token': AppSession.requiredToken,
            'p_user_id': userId,
            'p_plant_id': plantId,
          },
        )
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<String> upload(int plantId, String id, Uint8List bytes) async {
    final png =
        bytes.length >= 4 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final path = 'plant-$plantId/draft-$id.${png ? 'png' : 'jpg'}';
    try {
      await _client.storage
          .from('plant-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: png ? 'image/png' : 'image/jpeg',
            ),
          )
          .timeout(const Duration(seconds: 45));
    } on StorageException catch (error) {
      // Immutable path: a lost response can leave the first upload in place.
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    return _client.storage.from('plant-images').getPublicUrl(path);
  }

  @override
  Future<void> submit(int userId, Map<String, dynamic> draft) async {
    await _client
        .rpc(
          'submit_inspection_draft',
          params: {
            'p_session_token': AppSession.requiredToken,
            'p_user_id': userId,
            'p_request_id': draft['id'],
            'p_plant_id': draft['plantId'],
            'p_health_status_id': draft['healthId'],
            'p_growth_status_id': draft['growthId'],
            'p_observation': draft['observation'],
            'p_photo_url': draft['photoUrl'],
            'p_observed_at': draft['observedAt'],
          },
        )
        .timeout(const Duration(seconds: 30));
  }
}

class InspectionSyncService {
  InspectionSyncService({
    InspectionDraftStore? store,
    InspectionUploadBackend? backend,
  }) : store = store ?? InspectionDraftStore(),
       backend = backend ?? SupabaseInspectionUploadBackend();
  final InspectionDraftStore store;
  final InspectionUploadBackend backend;
  static final Set<String> _running = {};

  Future<void> submit(int userId, Map<String, dynamic> draft) async {
    if (draft['ready'] != true) {
      throw StateError('Review this draft before uploading.');
    }
    final id = draft['id'] as String;
    if (!_running.add(id)) {
      throw StateError('This inspection is already uploading.');
    }
    try {
      await backend.check(userId, draft['plantId'] as int);
      if (draft['photo'] != null && draft['photoUrl'] == null) {
        draft['photoUrl'] = await backend.upload(
          draft['plantId'] as int,
          id,
          Uint8List.fromList(base64Decode(draft['photo'] as String)),
        );
        await store.save(userId, draft);
      }
      await backend.submit(userId, draft);
      await store.remove(userId, id);
    } finally {
      _running.remove(id);
    }
  }
}
