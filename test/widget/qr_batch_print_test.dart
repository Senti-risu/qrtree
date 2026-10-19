import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/services/qr_batch_selection.dart';
import 'package:flutter_application_1/services/qr_service.dart';
import 'package:flutter_application_1/services/qr_print_service.dart';
import 'package:flutter_application_1/screens/qr/qr_management_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/qr_batch_print_dialog.dart';

Map<String, dynamic> tag(int id, [String status = 'damaged']) => {
  'qr_tag_id': id,
  'qr_code_string': 'ECOTAG-$id',
  'status': status,
};

class BatchTags extends QrService {
  BatchTags()
    : super(
        client: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final restored = <int>[];
  bool failSecond = false;
  @override
  Future<List<Map<String, dynamic>>> getTags({
    String? status,
    String? search,
    int limit = 500,
    int offset = 0,
  }) async => offset == 0 ? [tag(1), tag(2)] : [];
  @override
  Future<void> confirmReprinted({required int qrTagId}) async {
    if (failSecond && qrTagId == 2) throw Exception('offline');
    restored.add(qrTagId);
  }
}

class BatchPrinter extends QrPrintService {
  bool result = true;
  bool fail = false;
  List<Map<String, dynamic>>? printed;
  @override
  Future<bool> printBatch(List<Map<String, dynamic>> tags) async {
    if (fail) throw Exception('Printer unavailable');
    printed = tags;
    return result;
  }
}

Future<void> openDamagedBatch(
  WidgetTester tester,
  BatchTags service,
  BatchPrinter printer,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: QrManagementScreen(
        userId: 1,
        username: 'Admin',
        role: 'college_admin',
        qrService: service,
        printService: printer,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Damaged').last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Print'));
  await tester.pumpAndSettle();
  expect(find.text('Batch Reprint'), findsOneWidget);
  await tester.tap(find.text('Print 2'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'batch loads every page using the current search and damaged status',
    () async {
      final offsets = <int>[];
      final result = await loadPrintableQrBatch(
        filter: 'damaged',
        search: 'ECOTAG',
        loadPage:
            ({
              String? status,
              String? search,
              int limit = 100,
              int offset = 0,
            }) async {
              expect(status, 'damaged');
              expect(search, 'ECOTAG');
              offsets.add(offset);
              return List.generate(
                offset == 0 ? 100 : 3,
                (i) => tag(offset + i),
              );
            },
      );
      expect(result.length, 103);
      expect(offsets, [0, 100]);
    },
  );

  test('retired and replaced filters never load printable batches', () async {
    for (final status in ['retired', 'replaced']) {
      final result = await loadPrintableQrBatch(
        filter: status,
        search: '',
        loadPage:
            ({
              String? status,
              String? search,
              int limit = 100,
              int offset = 0,
            }) async {
              fail('Should not load terminal QR states');
            },
      );
      expect(result, isEmpty);
    }
  });

  test(
    'All preserves available-only default and rejects invalid/duplicate codes',
    () async {
      final result = await loadPrintableQrBatch(
        filter: 'all',
        search: '',
        loadPage:
            ({
              String? status,
              String? search,
              int limit = 100,
              int offset = 0,
            }) async {
              expect(status, 'available');
              return [
                tag(1, 'available'),
                tag(1, 'available'),
                tag(2),
                {...tag(3, 'available'), 'qr_code_string': ''},
              ];
            },
      );
      expect(result.map((t) => t['qr_tag_id']), [1]);
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets('batch selection works at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<Map<String, dynamic>>? selection;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selection = await showDialog<List<Map<String, dynamic>>>(
                    context: context,
                    builder: (_) => QrBatchPrintDialog(
                      tags: [tag(1), tag(2)],
                      status: 'damaged',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('2 selected'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(QrBatchPrintDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('2 selected'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Print 0'))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('ECOTAG-1'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(QrBatchPrintDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('ECOTAG-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Print 1'));
      await tester.pumpAndSettle();
      expect(selection?.single['qr_tag_id'], 1);
    });
  }

  testWidgets('top Print batches damaged labels and keeps damage if declined', (
    tester,
  ) async {
    final service = BatchTags();
    final printer = BatchPrinter();
    await openDamagedBatch(tester, service, printer);
    expect(printer.printed?.length, 2);
    expect(service.restored, isEmpty);
    await tester.tap(find.text('Keep Damaged'));
    await tester.pumpAndSettle();
    expect(service.restored, isEmpty);
  });

  testWidgets('cancelled print never restores damaged labels', (tester) async {
    final service = BatchTags();
    await openDamagedBatch(tester, service, BatchPrinter()..result = false);
    expect(find.text('Are all replacement QRs ready?'), findsNothing);
    expect(service.restored, isEmpty);
  });

  testWidgets('explicit batch confirmation restores each selected label', (
    tester,
  ) async {
    final service = BatchTags();
    await openDamagedBatch(tester, service, BatchPrinter());
    await tester.tap(find.text('Confirm All Ready'));
    await tester.pumpAndSettle();
    expect(service.restored, [1, 2]);
  });

  testWidgets('partial restoration failure reports the accurate count', (
    tester,
  ) async {
    final service = BatchTags()..failSecond = true;
    await openDamagedBatch(tester, service, BatchPrinter());
    await tester.tap(find.text('Confirm All Ready'));
    await tester.pumpAndSettle();
    expect(service.restored, [1]);
    expect(
      find.textContaining('1 QR tags restored; 1 could not'),
      findsOneWidget,
    );
  });

  testWidgets('print errors leave damage unchanged and allow retry', (
    tester,
  ) async {
    final service = BatchTags();
    await openDamagedBatch(tester, service, BatchPrinter()..fail = true);
    expect(service.restored, isEmpty);
    expect(find.text('Are all replacement QRs ready?'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Print'))
          .onPressed,
      isNotNull,
    );
  });
}
