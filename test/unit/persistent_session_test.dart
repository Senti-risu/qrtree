import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/app_role.dart';
import 'package:flutter_application_1/services/persistent_session.dart';

const token =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
Map<String, dynamic> identity({String role = 'college_admin'}) => {
  'user_id': 5,
  'username': 'CollegeAdmin',
  'role': role,
  'campus_id': 1,
  'college_id': 2,
  'is_active': true,
};

class MemoryTokenStore implements SessionTokenStore {
  String? value;
  bool failWrite = false;
  bool failDelete = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    if (failWrite) throw StateError('Storage failed');
    value = token;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('Delete failed');
    value = null;
  }
}

void main() {
  test(
    'background validation keeps login active during dashboard access checks',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var checks = 0;
      final session = PersistentSession(
        store: MemoryTokenStore(),
        validate: (_) =>
            ++checks == 1 ? pending.future : Future.value(identity()),
        revoke: (_) async {},
      );
      await session.start(token);
      final reminders = session.validateCurrent();
      expect(session.isAuthenticated, isTrue);
      expect(session.requiredToken, token);
      final dashboard = await session.validateCurrent();
      expect(dashboard?.dashboardRoute, '/dashboard');
      pending.complete(identity());
      expect((await reminders)?.userId, 5);
      expect(session.requiredToken, token);
    },
  );

  test(
    'background validation cannot reactivate a logged-out session',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final session = PersistentSession(
        store: MemoryTokenStore(),
        validate: (_) => pending.future,
        revoke: (_) async {},
      );
      await session.start(token);
      final checking = session.validateCurrent();
      await session.clear();
      pending.complete(identity());
      expect(await checking, isNull);
      expect(session.isAuthenticated, isFalse);
    },
  );

  test('background network failure preserves the active session', () async {
    final session = PersistentSession(
      store: MemoryTokenStore(),
      validate: (_) async => throw TimeoutException('offline'),
      revoke: (_) async {},
    );
    await session.start(token);
    await expectLater(
      session.validateCurrent(),
      throwsA(isA<TimeoutException>()),
    );
    expect(session.isAuthenticated, isTrue);
    expect(session.requiredToken, token);
  });

  PersistentSession manager(
    MemoryTokenStore store, {
    Future<Map<String, dynamic>> Function(String)? validate,
    Future<void> Function(String)? revoke,
  }) => PersistentSession(
    store: store,
    validate: validate ?? (_) async => identity(),
    revoke: revoke ?? (_) async {},
  );

  test(
    'only the token is stored and a new app instance restores from server',
    () async {
      final store = MemoryTokenStore();
      final first = manager(store);
      await first.start(token);
      expect(first.requiredToken, token);
      expect(store.value, token);
      final second = manager(
        store,
        validate: (saved) async {
          expect(saved, token);
          return {...identity(), 'username': 'Updated name', 'college_id': 3};
        },
      );
      final user = await second.restore();
      expect(user!.username, 'Updated name');
      expect(user.collegeId, 3);
      expect(second.requiredToken, token);
    },
  );

  for (final role in AppRole.values.where((r) => r != AppRole.unknown)) {
    test('restores ${role.value} to the correct dashboard', () async {
      final store = MemoryTokenStore()..value = token;
      final session = manager(
        store,
        validate: (_) async => identity(role: role.value),
      );
      final user = await session.restore();
      expect(
        user!.dashboardRoute,
        role == AppRole.superAdmin ? '/super-admin' : '/dashboard',
      );
      expect(user.arguments['role'], role.value);
    });
  }

  test('fresh installs remain signed out without calling the server', () async {
    var checks = 0;
    final session = manager(
      MemoryTokenStore(),
      validate: (_) async {
        checks++;
        return identity();
      },
    );
    expect(await session.restore(), isNull);
    expect(checks, 0);
    expect(session.isAuthenticated, isFalse);
  });

  test('expired or revoked server sessions are forgotten', () async {
    final store = MemoryTokenStore()..value = token;
    final session = manager(
      store,
      validate: (_) async => throw const PostgrestException(
        message: 'Your session has expired. Please sign in again.',
        code: 'P0001',
      ),
    );
    await expectLater(session.restore(), throwsA(isA<SessionRejected>()));
    expect(store.value, isNull);
    expect(session.isAuthenticated, isFalse);
  });

  test(
    'deactivated, unknown-role and missing-scope accounts are rejected',
    () async {
      for (final row in [
        {...identity(), 'is_active': false},
        {...identity(), 'role': 'unknown'},
        {...identity(), 'campus_id': null},
        {...identity(), 'college_id': null},
      ]) {
        final store = MemoryTokenStore()..value = token;
        final session = manager(store, validate: (_) async => row);
        await expectLater(session.restore(), throwsA(isA<SessionRejected>()));
        expect(store.value, isNull);
        expect(session.isAuthenticated, isFalse);
      }
    },
  );

  test(
    'temporary network failures retain the token but do not open the dashboard',
    () async {
      final store = MemoryTokenStore()..value = token;
      var offline = true;
      final session = manager(
        store,
        validate: (_) async {
          if (offline) throw TimeoutException('network');
          return identity();
        },
      );
      await expectLater(session.restore(), throwsA(isA<TimeoutException>()));
      expect(store.value, token);
      expect(session.isAuthenticated, isFalse);
      offline = false;
      expect(await session.restore(), isNotNull);
    },
  );

  test('logout clears local persistence even when server is offline', () async {
    final store = MemoryTokenStore();
    var revoked = false;
    final session = manager(
      store,
      revoke: (saved) async {
        expect(saved, token);
        revoked = true;
        throw TimeoutException('offline');
      },
    );
    await session.start(token);
    await session.end();
    expect(revoked, isTrue);
    expect(store.value, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(await manager(store).restore(), isNull);
  });

  test('storage failure never claims sign-in or logout succeeded', () async {
    final store = MemoryTokenStore()..failWrite = true;
    final session = manager(store);
    await expectLater(session.start(token), throwsStateError);
    expect(session.isAuthenticated, isFalse);
    store.failWrite = false;
    await session.start(token);
    store.failDelete = true;
    await expectLater(session.end(), throwsStateError);
    expect(session.isAuthenticated, isTrue);
  });

  test('an in-flight restoration cannot undo a logout', () async {
    final check = Completer<Map<String, dynamic>>();
    final store = MemoryTokenStore()..value = token;
    final session = manager(store, validate: (_) => check.future);
    final restore = session.restore();
    await Future<void>.delayed(Duration.zero);
    await session.end();
    check.complete(identity());
    expect(await restore, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(store.value, isNull);
  });

  test(
    'overlapping login and logout operations leave no saved token',
    () async {
      final store = MemoryTokenStore();
      final session = manager(store);
      final login = session.start(token);
      final logout = session.end();
      await Future.wait([login, logout]);
      expect(session.isAuthenticated, isFalse);
      expect(store.value, isNull);
    },
  );
}
