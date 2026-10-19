import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrPrintService {
  static const double labelSize = 2 * PdfPageFormat.inch;
  static const int labelsPerPage = 15;
  static const singleLabelFormat = PdfPageFormat(labelSize, labelSize);

  Future<bool> printSingleTag({
    required String qrCode,
    String title = 'EcoTag',
    String? subtitle,
  }) async {
    final bytes = await buildSingleTagPdf(
      qrCode: qrCode,
      title: title,
      subtitle: subtitle,
    );
    return Printing.layoutPdf(
      name: '$qrCode.pdf',
      format: singleLabelFormat,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildSingleTagPdf({
    required String qrCode,
    String title = 'EcoTag',
    String? subtitle,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: singleLabelFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) =>
            _labelTile(qrCode: qrCode, title: title, subtitle: subtitle),
      ),
    );
    return pdf.save();
  }

  Future<bool> printBatch(List<Map<String, dynamic>> tags) async {
    final bytes = await buildBatchPdf(tags);
    return Printing.layoutPdf(
      name: 'ecotag_qr_batch.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildBatchPdf(List<Map<String, dynamic>> tags) async {
    if (tags.isEmpty) throw Exception('There are no QR tags to print.');
    final pdf = pw.Document();
    const perPage = labelsPerPage;

    for (var start = 0; start < tags.length; start += perPage) {
      final end = (start + perPage < tags.length)
          ? start + perPage
          : tags.length;
      final chunk = tags.sublist(start, end);
      final rows = <pw.TableRow>[];

      for (var i = 0; i < chunk.length; i += 3) {
        final cells = <pw.Widget>[];
        for (var c = 0; c < 3; c++) {
          final index = i + c;
          if (index < chunk.length) {
            final code = chunk[index]['qr_code_string'].toString();
            cells.add(_labelTile(qrCode: code, title: 'EcoTag'));
          } else {
            cells.add(pw.SizedBox(width: labelSize, height: labelSize));
          }
        }
        rows.add(pw.TableRow(children: cells));
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.SizedBox(
              width: 3 * labelSize,
              child: pw.Table(
                columnWidths: const {
                  0: pw.FixedColumnWidth(labelSize),
                  1: pw.FixedColumnWidth(labelSize),
                  2: pw.FixedColumnWidth(labelSize),
                },
                children: rows,
              ),
            ),
          ),
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _labelTile({
    required String qrCode,
    required String title,
    String? subtitle,
  }) => pw.Container(
    width: labelSize,
    height: labelSize,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
    ),
    child: pw.Center(
      child: _label(qrCode: qrCode, title: title, subtitle: subtitle),
    ),
  );

  pw.Widget _label({
    required String qrCode,
    required String title,
    String? subtitle,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          height: 14,
          child: pw.FittedBox(
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.SizedBox(
            height: 9,
            child: pw.FittedBox(
              child: pw.Text(
                subtitle,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 3),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrCode,
          width: 90,
          height: 90,
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(
          height: 8,
          child: pw.FittedBox(
            child: pw.Text(
              qrCode,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        ),
      ],
    );
  }
}
