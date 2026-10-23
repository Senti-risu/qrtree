import 'package:flutter_application_1/services/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('campus summary PDF is generated with totals', () async {
    final bytes = await ReportExportService().campusSummaryPdf(
      rows: const [
        ['CSU Lasam', '10', '3', '1', '14'],
        ['TOTAL', '10', '3', '1', '14'],
      ],
      scope: 'All Campuses',
      filters: 'Campus: All',
      preparedBy: 'Universityadmin',
      generated: '2026-10-23 05:40',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
