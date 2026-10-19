import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_application_1/widgets/media_preview.dart';
import 'package:flutter_application_1/widgets/plant_ecotag_header.dart';
import 'package:flutter_application_1/screens/qr/qr_management_screen.dart';

void main() {
  testWidgets('QR details display the existing code and open its plant', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showQrDetails(
                context,
                code: 'ECOTAG-001',
                details: {'Status': 'Damaged'},
                onOpenPlant: () => opened = true,
              ),
              child: const Text('View QR'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('View QR'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'ECOTAG-001',
    );
    expect(find.text('Status: Damaged'), findsOneWidget);
    await tester.tap(find.text('View Plant Details'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text('QR Details'), findsNothing);
  });

  testWidgets('plant QR thumbnail opens a larger preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlantEcoTagHeader(code: 'ECOTAG-002')),
      ),
    );
    await tester.tap(find.byType(QrImageView));
    await tester.pumpAndSettle();
    expect(find.text('QR Details'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('QR Details'), findsNothing);
  });

  test('QR Management remains available', () {
    expect(
      const QrManagementScreen(
        userId: 1,
        username: 'Admin',
        role: 'college_admin',
      ),
      isA<StatefulWidget>(),
    );
  });
}
