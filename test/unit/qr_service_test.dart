import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/qr_service.dart';

void main() {
  group('QR lifecycle normalization', () {
    test('preserves active lifecycle states', () {
      expect(QrService.normalizedStatus('available'), 'available');
      expect(QrService.normalizedStatus('ASSIGNED'), 'assigned');
      expect(QrService.normalizedStatus(' damaged '), 'damaged');
      expect(QrService.normalizedStatus('replaced'), 'replaced');
    });

    test('maps legacy lost labels to retired', () {
      expect(QrService.normalizedStatus('lost'), 'retired');
      expect(QrService.normalizedStatus('retired'), 'retired');
    });

    test('uses canonical lifecycle field before legacy status', () {
      expect(
        QrService.statusOf({
          'lifecycle_status': 'replaced',
          'status': 'retired',
        }),
        'replaced',
      );
      expect(QrService.statusOf({'status': 'assigned'}), 'assigned');
    });
  });
}
