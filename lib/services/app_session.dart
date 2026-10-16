import 'package:supabase_flutter/supabase_flutter.dart';
import 'persistent_session.dart';

class AppSession {
  AppSession._();

  static final _session = PersistentSession(
    store: SecureSessionTokenStore(),
    validate: (token) async {
      final data = await Supabase.instance.client
          .rpc('app_session_status', params: {'p_session_token': token})
          .timeout(const Duration(seconds: 15));
      if (data is! List || data.length != 1 || data.first is! Map) {
        throw const SessionRejected();
      }
      return Map<String, dynamic>.from(data.first as Map);
    },
    revoke: (token) async {
      await Supabase.instance.client.rpc(
        'logout_user',
        params: {'p_session_token': token},
      );
    },
  );

  static bool get isAuthenticated => _session.isAuthenticated;

  static String get requiredToken => _session.requiredToken;

  static Future<void> start(String token) async {
    try {
      await _session.start(token);
    } catch (_) {
      try {
        await Supabase.instance.client
            .rpc('logout_user', params: {'p_session_token': token})
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      throw StateError(
        'Secure device storage is unavailable. Restart the '
        'updated app and try again.',
      );
    }
  }

  static Future<void> clear() => _session.clear();
  static Future<SessionIdentity?> restore() => _session.restore();

  static Future<void> end() => _session.end();
}
