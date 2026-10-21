import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/qr/qr_management_screen.dart';
import 'package:flutter_application_1/services/qr_print_service.dart';
import 'package:flutter_application_1/services/qr_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

class _LayoutQrService extends QrService {
  _LayoutQrService()
    : super(
        client: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<List<Map<String, dynamic>>> getTags({
    String? status,
    String? search,
    int limit = 500,
    int offset = 0,
  }) async => [
    {
      'qr_tag_id': 31,
      'qr_code_string': 'CSU-202610-000029',
      'status': 'assigned',
      'common_name': 'Mango',
      'plant_id': 12,
    },
  ];
}

class _LayoutQrPrinter extends QrPrintService {}

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(360, 800), 1.15),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets('QR management layout fits $size / $scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: QrManagementScreen(
            userId: 1,
            username: 'Admin',
            role: 'college_admin',
            qrService: _LayoutQrService(),
            printService: _LayoutQrPrinter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Clear filters and search'), findsNothing);
      expect(find.text('Filters'), findsNothing);
      final printBatch = find.text('Print Batch');
      final scanQr = find.text('Scan QR');
      expect(printBatch, findsOneWidget);
      expect(scanQr, findsOneWidget);
      final printRect = tester.getRect(printBatch);
      final scanRect = tester.getRect(scanQr);
      if (size.width >= 360 && scale <= 1.4) {
        expect((printRect.center.dy - scanRect.center.dy).abs(), lessThan(1));
      }
      final card = tester.getRect(find.text('CSU-202610-000029'));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opens QR filters from the icon button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
          qrService: _LayoutQrService(),
          printService: _LayoutQrPrinter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Filter QR Tags'), findsOneWidget);
    expect(find.text('Tag Status'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
