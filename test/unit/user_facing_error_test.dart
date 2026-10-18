import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/user_facing_error.dart';

void main() {
  group('userFacingError', () {
    test('explains a pending database migration without technical details', () {
      final message = userFacingError(
        Exception(
          "PostgrestException: Could not find the 'archived_at' column in the schema cache",
        ),
      );

      expect(message, contains('latest database update'));
      expect(message, isNot(contains('archived_at')));
    });

    test('explains a temporary account lock', () {
      final message = userFacingError(
        Exception(
          'Account temporarily locked after too many unsuccessful attempts',
        ),
      );

      expect(message, contains('15 minutes'));
    });
  });
}
