import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_application_1/widgets/plant_ecotag_header.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 1080.0]) {
    testWidgets(
      'EcoTag code stays complete above the existing photo at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const code = 'ECOTAG-1787485689155000-249784';
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: const TextScaler.linear(2),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const PlantEcoTagHeader(code: code),
                      Container(
                        key: const Key('existing-photo'),
                        height: 200,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(code), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          tester.getRect(find.byType(PlantEcoTagHeader)).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const Key('existing-photo'))).top,
          ),
        );
        await tester.tap(find.text('Copy code'));
        await tester.pumpAndSettle();
        expect(copied, code);
        expect(find.text('EcoTag code copied.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unassigned tags do not generate a fake QR payload', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlantEcoTagHeader())),
    );
    expect(find.text('No EcoTag assigned'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
}
