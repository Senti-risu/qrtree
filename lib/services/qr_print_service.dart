import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrPrintService {
  Future<void> printSingleTag({
    required String qrCode,
    String title = 'EcoTag',
    String? subtitle,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          3 * PdfPageFormat.inch,
          3 * PdfPageFormat.inch,
        ),
        margin: const pw.EdgeInsets.all(12),
        build: (_) => pw.Center(
          child: _label(
            qrCode: qrCode,
            title: title,
            subtitle: subtitle,
            qrSize: 125,
          ),
        ),
      ),
    );
    await Printing.layoutPdf(name: '$qrCode.pdf', onLayout: (_) => pdf.save());
  }

  Future<void> printBatch(List<Map<String, dynamic>> tags) async {
    if (tags.isEmpty) throw Exception('There are no QR tags to print.');
    final pdf = pw.Document();
    const perPage = 12;

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
            cells.add(
              pw.Container(
                height: 180,
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                ),
                child: _label(qrCode: code, title: 'EcoTag', qrSize: 105),
              ),
            );
          } else {
            cells.add(pw.SizedBox());
          }
        }
        rows.add(pw.TableRow(children: cells));
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.FlexColumnWidth(),
            },
            children: rows,
          ),
        ),
      );
    }

    await Printing.layoutPdf(
      name: 'ecotag_qr_batch.pdf',
      onLayout: (_) => pdf.save(),
    );
  }

  pw.Widget _label({
    required String qrCode,
    required String title,
    String? subtitle,
    required double qrSize,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.SizedBox(height: 7),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrCode,
          width: qrSize,
          height: qrSize,
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          qrCode,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
      ],
    );
  }
}
