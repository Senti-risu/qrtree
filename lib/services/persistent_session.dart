import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_role.dart';

class SessionRejected implements Exception {
  const SessionRejected();
}

class SessionIdentity {
  const SessionIdentity({
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });
  final int userId;
  final String username;
  final AppRole role;
  final int? campusId;
  final int? collegeId;

  factory SessionIdentity.fromServer(Map<String, dynamic> row) {
    final role = AppRole.fromValue(row['role']?.toString());
    final capabilities = RoleCapabilities(role);
    final id = row['user_id'];
    final campus = row['campus_id'];
    final college = row['college_id'];
    final name = row['username']?.toString().trim() ?? '';
    if (row['is_active'] != true ||
        id is! int ||
        id <= 0 ||
        name.isEmpty ||
        role == AppRole.unknown ||
        (capabilities.hasAssignedCampusScope &&
            (campus is! int || campus <= 0)) ||
        (capabilities.hasAssignedCollegeScope &&
            (college is! int || college <= 0))) {
      throw const SessionRejected();
    }
    return SessionIdentity(
      userId: id,
      username: name,
      role: role,
      campusId: campus is int ? campus : null,
      collegeId: college is int ? college : null,
    );
  }

  String get dashboardRoute =>
      role == AppRole.superAdmin ? '/super-admin' : '/dashboard';
  Map<String, dynamic> get arguments => {
    'user_id': userId,
    'username': username,
    'role': role.value,
    'campus_id': campusId,
    'college_id': collegeId,
  };
}

abstract interface class SessionTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureSessionTokenStore implements SessionTokenStore {
  static const _key = 'ecotag_session_v1';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Only the token is persisted. Identity/permissions are always fetched afresh.
class PersistentSession {
  PersistentSession({
    required this.store,
    required this.validate,
    required this.revoke,
  });
  final SessionTokenStore store;
  final Future<Map<String, dynamic>> Function(String token) validate;
  final Future<void> Function(String token) revoke;
  String? _token;
  int _generation = 0;
  Future<void> _pendingStorage = Future<void>.value();
  Future<T> _storeOperation<T>(Future<T> Function() operation) {
    final result = _pendingStorage.then((_) => operation());
    _pendingStorage = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  bool get isAuthenticated => _token?.isNotEmpty == true;
  String get requiredToken =>
      _token ??
      (throw StateError(
        'Your EcoTag session has expired. Please sign in again.',
      ));

  Future<void> start(String token) async {
    final value = token.trim();
    if (value.isEmpty) throw ArgumentError('Session token cannot be empty.');
    final generation = ++_generation;
    _token = null;
    await _storeOperation(() async {
      await store.delete();
      await store.write(value);
      if (await store.read() != value) {
        throw StateError('Secure device storage did not retain the session.');
      }
    });
    if (generation == _generation) _token = value;
  }

  Future<void> clear() async {
    ++_generation;
    // Do not report a successful logout if the device cannot forget the token.
    await _storeOperation(store.delete);
    _token = null;
  }

  /// Revalidate an active session without clearing it during background work.
  Future<SessionIdentity?> validateCurrent() async {
    final token = _token;
    final generation = _generation;
    if (token == null || token.isEmpty) return null;
    try {
      final row = await validate(token);
      if (generation != _generation || token != _token) return null;
      return SessionIdentity.fromServer(row);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('session has expired') ||
          message.contains('valid ecotag session is required')) {
        throw const SessionRejected();
      }
      rethrow;
    }
  }

  Future<SessionIdentity?> restore() async {
    final generation = ++_generation;
    _token = null;
    final token = await _storeOperation(store.read);
    if (generation != _generation || token == null || token.isEmpty) {
      return null;
    }
    try {
      if (token.trim().length < 32) throw const SessionRejected();
      final row = await validate(token);
      if (generation != _generation) return null;
      final identity = SessionIdentity.fromServer(row);
      _token = token;
      return identity;
    } catch (error) {
      if (generation != _generation) return null;
      final expired =
          error is SessionRejected ||
          (error is PostgrestException &&
              (error.message.toLowerCase().contains('session has expired') ||
                  error.message.toLowerCase().contains(
                    'valid ecotag session is required',
                  )));
      if (expired) {
        await clear();
        throw const SessionRejected();
      }
      // A temporary network/server failure must not discard a valid saved token.
      rethrow;
    }
  }

  Future<void> end() async {
    final token = _token;
    await clear();
    if (token == null) return;
    try {
      await revoke(token).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Local deletion completed, even if offline server revocation must wait
      // for this already-expiring token to reach its server-side expiry.
    }
  }
}
