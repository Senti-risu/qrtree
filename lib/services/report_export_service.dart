import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';
import 'report_export_data.dart';

class ReportExportService {
  Future<void> validatePlants(List<int> plantIds) async {
    for (
      var offset = 0;
      offset == 0 || offset < plantIds.length;
      offset += 200
    ) {
      final valid = await Supabase.instance.client
          .rpc(
            'report_validate_plants',
            params: {
              'p_session_token': AppSession.requiredToken,
              'p_plant_ids': plantIds.skip(offset).take(200).toList(),
            },
          )
          .timeout(const Duration(seconds: 30));
      if (valid != true) {
        throw StateError(
          'Report scope changed. Refresh the report and try again.',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> history(
    List<int> plantIds, {
    DateTime? start,
    DateTime? end,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var batch = 0; batch < plantIds.length; batch += 200) {
      final ids = plantIds.skip(batch).take(200).toList();
      for (var offset = 0; ; offset += 500) {
        final data = await Supabase.instance.client
            .rpc(
              'report_inspection_history',
              params: {
                'p_session_token': AppSession.requiredToken,
                'p_plant_ids': ids,
                'p_start_on': start == null
                    ? null
                    : ReportExportData.date(start),
                'p_end_on': end == null ? null : ReportExportData.date(end),
                'p_offset': offset,
                'p_limit': 500,
              },
            )
            .timeout(const Duration(seconds: 30));
        final rows = List<Map<String, dynamic>>.from(data as List);
        result.addAll(rows);
        if (rows.length < 500) break;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> outcomes() async => Map<String, dynamic>.from(
    await Supabase.instance.client
            .rpc(
              'monitoring_outcomes',
              params: {'p_session_token': AppSession.requiredToken},
            )
            .timeout(const Duration(seconds: 30))
        as Map,
  );

  Future<bool> saveCsv(ExportReport report, String filename) async {
    final saved = await FileSaver.instance.saveAs(
      name: filename,
      bytes: report.csvBytes(),
      fileExtension: 'csv',
      mimeType: MimeType.custom,
      customMimeType: 'text/csv',
    );
    return saved != null;
  }

  static final _ink = PdfColor.fromHex('#1C3029');
  static final _green = PdfColor.fromHex('#176344');
  static final _line = PdfColor.fromHex('#E6EBE5');

  /// Split long notes across continuation rows rather than clipping a page.
  static List<List<String>> printableRows(List<List<String>> rows) => [
    for (final row in rows)
      for (
        var start = 0;
        start < row.map((s) => s.length).fold<int>(1, (a, b) => a > b ? a : b);
        start += 240
      )
        [
          for (final cell in row)
            start == 0
                ? cell.substring(0, cell.length.clamp(0, 240))
                : start < cell.length
                ? '(continued) ${cell.substring(start, (start + 240).clamp(0, cell.length))}'
                : cell.length <= 240
                ? cell
                : '',
        ],
  ];

  Future<Uint8List> pdfBytes(ExportReport report) async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final document = pw.Document(
      title: 'EcoTag - ${report.kind.label}',
      author: report.metadata['Prepared by'],
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 10000,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EcoTag',
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                ),
              ),
              pw.Text(
                report.kind.label,
                style: pw.TextStyle(fontSize: 10, color: _ink),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated ${report.metadata['Generated (Asia/Manila)']} (Asia/Manila)',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 16),
          pw.Text(
            report.kind.label,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 10),
          for (final entry in report.metadata.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '${entry.key}: ${entry.value}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          if (report.kind == ReportKind.health) ...[
            pw.SizedBox(height: 16),
            ...report.sections.first.rows.map(
              (row) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 105,
                      child: pw.Text(
                        row[0],
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 300,
                      child: pw.Row(
                        children: [
                          pw.Container(
                            height: 10,
                            width:
                                (double.tryParse(row[2].replaceAll('%', '')) ??
                                        0)
                                    .clamp(0, 100) *
                                3,
                            color: _green,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      '${row[1]} (${row[2]})',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final section in report.sections) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              section.title,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
            if (section.note != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5),
                child: pw.Text(
                  section.note!,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            pw.SizedBox(height: 8),
            if (section.rows.isEmpty)
              pw.Text(
                'No matching records.',
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.TableHelper.fromTextArray(
                columnWidths: {
                  for (var i = 0; i < section.headers.length; i++)
                    i: pw.FlexColumnWidth(switch (section.headers[i]) {
                      'Findings / Remarks' => 2.6,
                      'Location' || 'College' || 'Scientific Name' => 1.7,
                      'QR ID' || 'Tree Planter' => 1.3,
                      'Inspection ID' => 0.7,
                      _ => 1.0,
                    }),
                },
                headers: section.headers,
                data: printableRows(section.rows),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EDF4E8'),
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
                cellStyle: pw.TextStyle(fontSize: 8, color: _ink),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: _line, width: 0.5),
              ),
          ],
        ],
      ),
    );
    return document.save();
  }
}
