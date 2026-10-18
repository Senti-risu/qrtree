import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/inspection_draft_store.dart';
import 'package:flutter_application_1/services/inspection_sync_service.dart';
import 'package:flutter_application_1/utils/user_facing_error.dart';

class FakeBackend implements InspectionUploadBackend {
  bool reject = false, loseResponse = false;
  int uploads = 0, submissions = 0;
  final Set<String> records = {};
  Completer<void>? waiting;
  @override
  Future<void> check(int userId, int plantId) async {
    if (reject) throw StateError('Assignment changed');
    if (waiting != null) await waiting!.future;
  }

  @override
  Future<String> upload(int plantId, String id, Uint8List bytes) async {
    uploads++;
    expect(bytes, [1, 2, 3]);
    return 'https://example.test/$id.jpg';
  }

  @override
  Future<void> submit(int userId, Map<String, dynamic> draft) async {
    submissions++;
    records.add(draft['id'] as String);
    if (loseResponse) {
      loseResponse = false;
      throw TimeoutException('Response lost');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'upload conflicts explain recovery without exposing database details',
    () {
      expect(
        userFacingError(
          StateError(
            'A newer inspection exists. Review this draft before submitting',
          ),
        ),
        contains('Review the plant history'),
      );
      expect(
        userFacingError(
          StateError(
            'Plant is archived or Dead; inspection remains saved for review',
          ),
        ),
        contains('College Admin'),
      );
      expect(
        userFacingError(StateError('Plant is outside your assigned college')),
        contains('draft is still saved'),
      );
    },
  );
  Map<String, dynamic> draft() => {
    'id': InspectionDraftStore.newId(),
    'plantId': 8,
    'plant': {'plant_id': 8},
    'ready': true,
    'healthId': 1,
    'growthId': 2,
    'observation': 'Leaves yellow',
    'observedAt': '2026-10-18T01:00:00Z',
    'photo': base64Encode([1, 2, 3]),
  };

  test('photos survive reopening and account data stays separate', () async {
    final value = draft();
    await InspectionDraftStore().save(1, value);
    expect(await InspectionDraftStore().list(1), [value]);
    expect(await InspectionDraftStore().list(2), isEmpty);
    await InspectionDraftStore().cachePlants(1, [
      {'plant_id': 8},
    ]);
    expect(await InspectionDraftStore().plants(2), isEmpty);
    expect(await InspectionDraftStore().plants(1), [
      {'plant_id': 8},
    ]);
  });

  test('authorization failure retains evidence without uploading', () async {
    final store = InspectionDraftStore();
    final backend = FakeBackend()..reject = true;
    final value = draft();
    await store.save(1, value);
    await expectLater(
      InspectionSyncService(store: store, backend: backend).submit(1, value),
      throwsStateError,
    );
    expect(backend.uploads, 0);
    expect(await store.list(1), [value]);
  });

  test('lost response retains stable ID and photo URL for retry', () async {
    final store = InspectionDraftStore();
    final backend = FakeBackend()..loseResponse = true;
    final value = draft();
    await store.save(1, value);
    final service = InspectionSyncService(store: store, backend: backend);
    await expectLater(
      service.submit(1, value),
      throwsA(isA<TimeoutException>()),
    );
    final restored = (await InspectionDraftStore().list(1)).single;
    expect(restored['id'], value['id']);
    expect(restored['photoUrl'], isNotNull);
    expect(restored['observedAt'], '2026-10-18T01:00:00Z');
    await service.submit(1, restored);
    expect(backend.uploads, 1);
    expect(backend.records, {value['id']});
    expect(await store.list(1), isEmpty);
  });

  test(
    'concurrent uploads are refused and unconfirmed drafts stay local',
    () async {
      final store = InspectionDraftStore();
      final backend = FakeBackend()..waiting = Completer<void>();
      final value = draft();
      await store.save(1, value);
      final service = InspectionSyncService(store: store, backend: backend);
      final first = service.submit(1, value);
      await expectLater(service.submit(1, value), throwsStateError);
      backend.waiting!.complete();
      await first;
      value['ready'] = false;
      await store.save(1, value);
      await expectLater(service.submit(1, value), throwsStateError);
      expect(await store.list(1), isNotEmpty);
    },
  );
}
