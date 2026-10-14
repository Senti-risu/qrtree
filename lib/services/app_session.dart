import 'package:supabase_flutter/supabase_flutter.dart';

class AppSession {
  AppSession._();

  static String? _token;

  static bool get isAuthenticated => _token?.isNotEmpty == true;

  static String get requiredToken {
    final value = _token;
    if (value == null || value.isEmpty) {
      throw StateError(
        'Your EcoTag session has expired. Please sign in again.',
      );
    }
    return value;
  }

  static void start(String token) {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Session token cannot be empty.',
      );
    }
    _token = value;
  }

  static void clear() => _token = null;

  static Future<void> end() async {
    final token = _token;
    _token = null;
    if (token == null || token.isEmpty) return;

    try {
      await Supabase.instance.client
          .rpc('logout_user', params: {'p_session_token': token})
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Local logout must always succeed, including while offline or before
      // the production-readiness migration has been applied.
    }
  }
}
