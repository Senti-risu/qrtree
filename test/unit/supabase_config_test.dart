import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/config/supabase_config.dart';

void main() {
  test('URL uses the supplied build define or a valid development default', () {
    if (const bool.hasEnvironment('SUPABASE_URL')) {
      expect(SupabaseConfig.url, const String.fromEnvironment('SUPABASE_URL'));
    } else {
      final uri = Uri.parse(SupabaseConfig.url);
      expect(uri.scheme, 'https');
      expect(uri.host.isNotEmpty, isTrue);
    }
  });

  test(
    'publishable key takes precedence and legacy GitHub define is supported',
    () {
      if (const bool.hasEnvironment('SUPABASE_PUBLISHABLE_KEY')) {
        expect(
          SupabaseConfig.publishableKey,
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        );
      } else if (const bool.hasEnvironment('SUPABASE_ANON_KEY')) {
        expect(
          SupabaseConfig.publishableKey,
          const String.fromEnvironment('SUPABASE_ANON_KEY'),
        );
      } else {
        expect(SupabaseConfig.publishableKey.isNotEmpty, isTrue);
      }
    },
  );
}
