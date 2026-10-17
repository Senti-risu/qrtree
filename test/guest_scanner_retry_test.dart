import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/public/guest_qr_scanner_screen.dart';
import 'package:flutter_application_1/screens/public/guest_plant_detail_screen.dart';
import 'package:flutter_application_1/services/guest_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

class FakeCamera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  StartOptions? options;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    options = startOptions;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  void scan(String code) =>
      captures.add(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
}

class FakeGuestLookup extends GuestService {
  FakeGuestLookup()
    : super(
        supabase: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int calls = 0;
  bool fails = true;
  Completer<GuestQrScanResult>? pending;
  @override
  Future<GuestQrScanResult> scanPlantByQr({
    required int visitId,
    required String code,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fails) throw Exception('temporary failure');
    return GuestQrScanResult(
      status: 'assigned',
      message: 'Plant found',
      plant: GuestPlantProfile(
        plantId: 6,
        qrCode: code,
        commonName: 'Cacao',
        scientificName: 'Theobroma cacao',
        plantType: 'tree',
      ),
    );
  }
}

void main() {
  late FakeCamera camera;
  late MobileScannerPlatform previous;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    previous = MobileScannerPlatform.instance;
    camera = FakeCamera();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    MobileScannerPlatform.instance = previous;
    await camera.captures.close();
  });

  Future<void> open(WidgetTester tester, FakeGuestLookup service) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GuestQrScannerScreen(visitId: 1, service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(camera.options?.detectionSpeed, DetectionSpeed.normal);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'same QR can be retried after failure without flooding the backend',
    (tester) async {
      final service = FakeGuestLookup();
      await open(tester, service);
      camera.scan('ECOTAG-202610-000003');
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      camera.scan('ECOTAG-202610-000003');
      await tester.pump(const Duration(seconds: 3));
      expect(service.calls, 1);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      service.fails = false;
      camera.scan('ECOTAG-202610-000003');
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.byType(GuestPlantDetailScreen), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets('returning from a profile does not reopen it until Scan again', (
    tester,
  ) async {
    final service = FakeGuestLookup()..fails = false;
    await open(tester, service);
    camera.scan('ECOTAG-202610-000003');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    camera.scan('ECOTAG-202610-000003');
    await tester.pump(const Duration(seconds: 3));
    expect(service.calls, 1);
    expect(find.byType(GuestPlantDetailScreen), findsNothing);
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    camera.scan('ECOTAG-202610-000003');
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.byType(GuestPlantDetailScreen), findsOneWidget);
    await close(tester);
  });
  testWidgets('duplicate detections during a lookup issue only one request', (
    tester,
  ) async {
    final service = FakeGuestLookup()..pending = Completer<GuestQrScanResult>();
    await open(tester, service);
    camera.scan('ECOTAG-202610-000003');
    await tester.pump();
    camera.scan('ECOTAG-202610-000003');
    await tester.pump();
    expect(service.calls, 1);
    service.pending!.complete(
      const GuestQrScanResult(status: 'available', message: 'Not assigned yet'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not assigned yet'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
    await close(tester);
  });
  testWidgets(
    'manual entry retries the same code and ignores camera frames behind the dialog',
    (tester) async {
      final service = FakeGuestLookup();
      await open(tester, service);
      camera.scan('ECOTAG-202610-000003');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Enter code'));
      await tester.pumpAndSettle();
      camera.scan('ECOTAG-202610-000004');
      await tester.pump();
      expect(service.calls, 1);
      await tester.enterText(find.byType(TextField), 'ECOTAG-202610-000003');
      service.fails = false;
      await tester.tap(find.text('View plant'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.byType(GuestPlantDetailScreen), findsOneWidget);
      await close(tester);
    },
  );
}
