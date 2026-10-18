import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/registration_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  String key({
    int user = 1,
    int campus = 2,
    int college = 3,
    int? qr,
    String role = 'college_admin',
  }) => RegistrationDraftStore.keyFor(
    userId: user,
    role: role,
    campusId: campus,
    collegeId: college,
    qrTagId: qr,
  );

  test('draft and photo survive a new storage instance', () async {
    final data = {
      'variety': 'Native',
      'photoName': 'plant.jpg',
      'photo': base64Encode([1, 2, 3]),
      'classificationId': 9,
    };
    await RegistrationDraftStore().save(key(), data);
    expect(await RegistrationDraftStore().read(key()), data);
  });

  test('accounts, assignments, roles and QR contexts are isolated', () async {
    await RegistrationDraftStore().save(key(), {'planter': 'Owner'});
    for (final other in [
      key(user: 2),
      key(campus: 4),
      key(college: 4),
      key(qr: 10),
      key(role: 'inspection_team'),
    ]) {
      expect(await RegistrationDraftStore().read(other), isNull);
    }
  });

  test('discard removes only the requested draft', () async {
    final store = RegistrationDraftStore();
    await store.save(key(), {'variety': 'First'});
    await store.save(key(user: 2), {'variety': 'Second'});
    await store.discard(key());
    expect(await store.read(key()), isNull);
    expect(await store.read(key(user: 2)), {'variety': 'Second'});
  });

  test('successful registration cannot resume a stale draft', () async {
    final store = RegistrationDraftStore();
    await store.save(key(), {'variety': 'Complete'});
    await store.complete(key());
    expect(await store.read(key()), isNull);
    FlutterSecureStorage.setMockInitialValues({
      key(): '{"version":1,"completed":true}',
    });
    expect(await store.read(key()), isNull);
  });

  test(
    'corrupt or unsupported drafts fail without silently deleting data',
    () async {
      for (final raw in [
        'broken',
        '{"version":2,"data":{}}',
        '{"version":1,"data":[]}',
      ]) {
        FlutterSecureStorage.setMockInitialValues({key(): raw});
        await expectLater(
          RegistrationDraftStore().read(key()),
          throwsFormatException,
        );
        expect(await const FlutterSecureStorage().read(key: key()), raw);
      }
    },
  );
}
