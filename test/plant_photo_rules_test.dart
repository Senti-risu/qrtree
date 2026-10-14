import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/admin/plant_service.dart';

void main() {
  group('PlantPhotoRules', () {
    test('normalizes common image extensions', () {
      expect(PlantPhotoRules.normalizeExtension('.JPG'), 'jpg');
      expect(PlantPhotoRules.normalizeExtension('jpeg'), 'jpg');
      expect(PlantPhotoRules.normalizeExtension(' PNG '), 'png');
    });

    test('accepts supported non-empty photos within the limit', () {
      final extension = PlantPhotoRules.validate(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'jpeg',
      );

      expect(extension, 'jpg');
      expect(PlantPhotoRules.contentType(extension), 'image/jpeg');
    });

    test('rejects unsupported or empty photos', () {
      expect(
        () => PlantPhotoRules.validate(
          bytes: Uint8List.fromList([1]),
          extension: 'gif',
        ),
        throwsFormatException,
      );
      expect(
        () => PlantPhotoRules.validate(bytes: Uint8List(0), extension: 'jpg'),
        throwsFormatException,
      );
    });

    test('rejects photos larger than six megabytes', () {
      expect(
        () => PlantPhotoRules.validate(
          bytes: Uint8List(PlantPhotoRules.maxBytes + 1),
          extension: 'png',
        ),
        throwsFormatException,
      );
    });
  });
}
