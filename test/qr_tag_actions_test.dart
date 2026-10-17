import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/full_width_data_table.dart';
import 'package:flutter_application_1/widgets/qr_tag_actions.dart';

void main() {
  const allowed = {
    'available': 'Retire label',
    'assigned': 'Mark damaged',
    'damaged': 'Replace label',
  };
  for (final status in [
    'available',
    'assigned',
    'damaged',
    'replaced',
    'retired',
    'unknown',
  ]) {
    testWidgets('$status only exposes its allowed lifecycle action', (
      tester,
    ) async {
      var prints = 0;
      final changes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: QrTagActions(
              status: status,
              onPrint: () => prints++,
              onRetire: () => changes.add('Retire label'),
              onMarkDamaged: () => changes.add('Mark damaged'),
              onReplace: () => changes.add('Replace label'),
            ),
          ),
        ),
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.text('Print'));
      expect(prints, 1);
      for (final label in allowed.values) {
        expect(
          find.text(label),
          label == allowed[status] ? findsOneWidget : findsNothing,
        );
      }
      if (allowed.containsKey(status)) {
        await tester.tap(find.text(allowed[status]!));
        expect(changes, [allowed[status]]);
      } else {
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(changes, isEmpty);
      }
    });
  }

  for (final status in allowed.keys) {
    testWidgets('pending $status actions cannot be submitted twice', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: QrTagActions(
              status: status,
              busy: true,
              onPrint: () => presses++,
              onRetire: () => presses++,
              onMarkDamaged: () => presses++,
              onReplace: () => presses++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Print'));
      await tester.tap(find.text(allowed[status]!));
      expect(presses, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  }

  testWidgets('missing payload cannot be printed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrTagActions(
            status: 'available',
            onPrint: null,
            onRetire: () {},
            onMarkDamaged: () {},
            onReplace: () {},
          ),
        ),
      ),
    );
    final print = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Print'),
    );
    expect(print.onPressed, isNull);
  });

  for (final width in [320.0, 900.0, 1400.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('QR actions fit mobile or table at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget actions(String status) => QrTagActions(
          status: status,
          onPrint: () {},
          onRetire: () {},
          onMarkDamaged: () {},
          onReplace: () {},
        );
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
                  child: width < 600
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: allowed.keys.map(actions).toList(),
                          ),
                        )
                      : FullWidthDataTable(
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
                              columnWidth: FlexColumnWidth(1.6),
                            ),
                            DataColumn(
                              label: Text('ACTIONS'),
                              columnWidth: FlexColumnWidth(3.2),
                            ),
                          ],
                          rows: allowed.keys
                              .map(
                                (status) => DataRow(
                                  cells: [
                                    const DataCell(
                                      Text('ECOTAG-202610-000020'),
                                    ),
                                    const DataCell(Text('22')),
                                    DataCell(Text(status)),
                                    DataCell(actions(status)),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            ),
          ),
        );
        for (final label in allowed.values) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
