import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/services/report_export_data.dart';
import 'package:flutter_application_1/widgets/report_export_dialog.dart';

void main() {
  for (final width in [320.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('report export choices remain reachable at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ReportExportChoice? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        result = await showDialog<ReportExportChoice>(
                          context: context,
                          builder: (_) => const ReportExportDialog(),
                        ),
                    child: const Text('Export'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<ReportKind>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspection History').last);
        await tester.pumpAndSettle();
        expect(find.text('All Inspection Dates'), findsOneWidget);
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<ReportExportFormat>),
        );
        await tester.tap(
          find.byType(DropdownButtonFormField<ReportExportFormat>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Spreadsheet (CSV for Excel)').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(result?.kind, ReportKind.history);
        expect(result?.format, ReportExportFormat.csv);
        expect(result?.period, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
