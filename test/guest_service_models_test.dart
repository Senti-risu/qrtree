import 'package:flutter_application_1/services/guest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuestQrScanResult', () {
    test('parses an assigned public plant profile', () {
      final result = GuestQrScanResult.fromJson({
        'result_status': 'ASSIGNED',
        'message': 'Plant details found.',
        'plant': {
          'qr_code': 'ECOTAG-202610-000001',
          'plant_id': 42,
          'common_name': 'Narra',
          'scientific_name': 'Pterocarpus indicus',
          'plant_type': 'Tree',
          'campus_name': 'CSU Lasam',
          'health_status': 'Healthy',
        },
      });

      expect(result.status, 'assigned');
      expect(result.canView, isTrue);
      expect(result.plant?.plantId, 42);
      expect(result.plant?.qrCode, 'ECOTAG-202610-000001');
      expect(result.plant?.commonName, 'Narra');
      expect(result.plant?.campusName, 'CSU Lasam');
      expect(result.plant?.healthStatus, 'Healthy');
    });

    test('parses a lifecycle message without exposing a profile', () {
      final result = GuestQrScanResult.fromJson({
        'result_status': 'replaced',
        'message': 'Scan the newer label.',
        'plant': null,
      });

      expect(result.status, 'replaced');
      expect(result.message, 'Scan the newer label.');
      expect(result.canView, isFalse);
      expect(result.plant, isNull);
    });

    test('rejects an assigned profile without a valid plant ID', () {
      expect(
        () => GuestQrScanResult.fromJson({
          'result_status': 'assigned',
          'message': 'Plant details found.',
          'plant': {'plant_id': 0, 'common_name': 'Narra'},
        }),
        throwsFormatException,
      );
    });
  });
}
