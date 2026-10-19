import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_colors.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  // Initialize the scanner controller
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    // Start the camera automatically when the screen opens
    controller = MobileScannerController(
      detectionSpeed:
          DetectionSpeed.noDuplicates, // Prevents scanning the same QR twice
    );
  }

  @override
  void dispose() {
    // Stop the camera when you leave the screen to save battery
    controller.dispose();
    super.dispose();
  }

  // This function runs whenever a QR code is detected
  void _handleDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        debugPrint('QR Code detected: $code');

        // FUTURE: We will add navigation to the Details page here soon!
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Tag'),
        centerTitle: true,
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.onPrimary,
        actions: [
          // Flashlight toggle button
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () {
              controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. THE CAMERA FEED
          MobileScanner(controller: controller, onDetect: _handleDetect),

          // 2. THE SCANNING FRAME (White box)
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // 3. INSTRUCTION TEXT
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Align The QR Code Inside The Box',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
