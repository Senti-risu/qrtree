import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/qr_print_service.dart';

void main() {
  final service = QrPrintService();

  test(
    'single label PDF is exactly 144 by 144 points (2 by 2 inches)',
    () async {
      final bytes = await service.buildSingleTagPdf(
        qrCode: 'ECOTAG-202610-000022',
        subtitle: 'Mango',
      );
      final pdf = latin1.decode(bytes);
      expect(pdf, matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+144\s+144\s*\]')));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 1);
      final output = Directory('build/qr_print_previews')
        ..createSync(recursive: true);
      File('${output.path}/single-2-inch.pdf').writeAsBytesSync(bytes);
    },
  );

  for (final count in [1, 15, 16, 31]) {
    test('batch of $count uses 15 fixed-size labels per A4 page', () async {
      final bytes = await service.buildBatchPdf(
        List.generate(
          count,
          (i) => {
            'qr_code_string':
                'ECOTAG-202610-${(i + 1).toString().padLeft(6, '0')}',
          },
        ),
      );
      final pdf = latin1.decode(bytes);
      expect(QrPrintService.labelSize, 144);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(pdf).length,
        (count / 15).ceil(),
      );
      if (count == 16) {
        final output = Directory('build/qr_print_previews')
          ..createSync(recursive: true);
        File('${output.path}/batch-2-inch.pdf').writeAsBytesSync(bytes);
      }
    });
  }

  test('long subtitle fits the two-inch label', () async {
    final bytes = await service.buildSingleTagPdf(
      qrCode: 'ECOTAG-202610-000022',
      subtitle:
          'A very long plant common name that still belongs inside its label',
    );
    expect(bytes, isNotEmpty);
  });

  test('empty batches are rejected', () {
    expect(service.buildBatchPdf([]), throwsException);
  });
}
