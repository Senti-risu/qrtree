import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/full_width_data_table.dart';

void main() {
  for (final width in [600.0, 900.0, 1400.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('QR table fills width $width with text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var printed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  child: FullWidthDataTable(
                    columns: const [
                      DataColumn(
                        label: Text('QR CODE'),
                        columnWidth: FlexColumnWidth(4),
                      ),
                      DataColumn(
                        label: Text('ID'),
                        columnWidth: FlexColumnWidth(1.2),
                      ),
                      DataColumn(
                        label: Text('STATUS'),
                        columnWidth: FlexColumnWidth(2),
                      ),
                      DataColumn(
                        label: Text('ACTION'),
                        columnWidth: FlexColumnWidth(2),
                      ),
                    ],
                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.qr_code, size: 40),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'ECOTAG-202610-000020-123456789012345678901234567890',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const DataCell(Text('22')),
                          const DataCell(Text('Available')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Print QR',
                                  onPressed: () => printed = true,
                                  icon: const Icon(Icons.print),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.more_vert),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final tableWidth = tester.getSize(find.byType(DataTable)).width;
        expect(tableWidth, greaterThanOrEqualTo(width));
        if (width >= 900 && scale == 1) {
          expect(tableWidth, width);
          expect(
            tester.getTopLeft(find.text('ACTION')).dx,
            greaterThan(width * .7),
          );
        }
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        );
        if (tableWidth > width) {
          await tester.drag(horizontal, Offset(-(tableWidth - width), 0));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Print QR'));
        expect(printed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
