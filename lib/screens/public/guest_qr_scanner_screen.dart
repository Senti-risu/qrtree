import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/plant_details_presentation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/guest_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import 'guest_plant_detail_screen.dart';

enum _GuestScanMessageType { neutral, progress, success, error }

/// Read-only QR scanner for public visitors.
///
/// QR resolution stays in [GuestService], where the database returns only the
/// public plant profile. This screen never opens registration, inspection, or
/// administration actions.
class GuestQrScannerScreen extends StatefulWidget {
  const GuestQrScannerScreen({super.key, required this.visitId, this.service});

  final int visitId;
  final GuestService? service;

  @override
  State<GuestQrScannerScreen> createState() => _GuestQrScannerScreenState();
}

class _GuestQrScannerScreenState extends State<GuestQrScannerScreen>
    with WidgetsBindingObserver {
  late final GuestService _service;
  final MobileScannerController _controller = MobileScannerController(
    // Native noDuplicates remembers a failed label even after UI-only retries.
    // Repeated detections are gated below, so an explicit retry can use it again.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
  );

  bool _handling = false;
  bool _awaitingRetry = false;
  bool _manualEntryOpen = false;
  String _message =
      'Place an EcoTag QR inside the frame. You can also enter its code manually.';
  _GuestScanMessageType _messageType = _GuestScanMessageType.neutral;
  String? _lastCode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GuestService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handling) unawaited(_startCameraSafely());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  Future<void> _handleCode(String rawCode) async {
    final code = rawCode.trim();
    if (_handling || _manualEntryOpen || code.isEmpty) return;
    if (_awaitingRetry && code == _lastCode) return;

    final now = DateTime.now();
    if (_lastCode == code &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastCode = code;
    _lastScanAt = now;
    setState(() {
      _handling = true;
      _awaitingRetry = false;
      _message = 'Checking this EcoTag…';
      _messageType = _GuestScanMessageType.progress;
    });

    try {
      final result = await _service.scanPlantByQr(
        visitId: widget.visitId,
        code: code,
      );
      if (!mounted) return;

      final plant = result.plant;
      if (result.canView && plant != null) {
        await HapticFeedback.mediumImpact();
        await _controller.stop();
        if (!mounted) return;

        await Navigator.push(
          context,
          plantDetailsRoute(
            builder: (_) => GuestPlantDetailScreen(plant: plant),
          ),
        );
        if (!mounted) return;

        await _startCameraSafely();
        if (!mounted) return;
        setState(() {
          _handling = false;
          // Do not reopen the same profile immediately while its label remains
          // in the camera frame. A different label or Scan again is accepted.
          _awaitingRetry = true;
          _message = 'Plant profile opened. Ready to scan another QR.';
          _messageType = _GuestScanMessageType.success;
        });
        return;
      }

      await HapticFeedback.vibrate();
      if (!mounted) return;
      setState(() {
        _handling = false;
        _awaitingRetry = true;
        _message = result.message;
        _messageType = _isNeutralStatus(result.status)
            ? _GuestScanMessageType.neutral
            : _GuestScanMessageType.error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _handling = false;
        _awaitingRetry = true;
        _message = userFacingError(
          error,
          fallback: 'The QR could not be checked. Please try again.',
        );
        _messageType = _GuestScanMessageType.error;
      });
    }
  }

  bool _isNeutralStatus(String value) => const {
    'available',
    'damaged',
    'replaced',
    'retired',
    'unavailable',
  }.contains(value.trim().toLowerCase());

  Future<void> _startCameraSafely() async {
    try {
      await _controller.start();
    } catch (_) {
      // The camera error view still offers manual code entry.
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      _showCameraMessage('The flashlight is not available on this device.');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {
      _showCameraMessage('A second camera is not available on this device.');
    }
  }

  void _showCameraMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showManualEntry() async {
    if (_handling || _manualEntryOpen) return;
    _manualEntryOpen = true;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _GuestCodeEntryDialog(),
    );
    _manualEntryOpen = false;
    if (!mounted) return;
    if (code != null && code.isNotEmpty) {
      _awaitingRetry = false;
      _lastCode = null;
      _lastScanAt = null;
      await _handleCode(code);
    }
  }

  void _resetScanner() {
    if (_handling) return;
    setState(() {
      _handling = false;
      _awaitingRetry = false;
      _lastCode = null;
      _lastScanAt = null;
      _message = 'Place another EcoTag QR inside the frame.';
      _messageType = _GuestScanMessageType.neutral;
    });
    unawaited(_startCameraSafely());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scannerBackground,
      appBar: AppBar(
        title: const Text('Scan EcoTag'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.scannerBackground,
        actions: [
          IconButton(
            tooltip: 'Toggle Flashlight',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch Camera',
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) =>
                          _CameraErrorView(onEnterCode: _showManualEntry),
                      placeholderBuilder: (_) => const ColoredBox(
                        color: AppColors.scannerBackground,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                    const _GuestScannerOverlay(),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Text(
                        'Hold your phone steady and keep the whole code visible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .92),
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .48,
                ),
                child: SingleChildScrollView(child: _statusPanel()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        unawaited(_handleCode(value));
        break;
      }
    }
  }

  Widget _statusPanel() {
    final color = switch (_messageType) {
      _GuestScanMessageType.success => AppColors.green,
      _GuestScanMessageType.error => AppColors.danger,
      _GuestScanMessageType.progress => AppColors.green,
      _GuestScanMessageType.neutral => AppColors.textSecondary,
    };
    final icon = switch (_messageType) {
      _GuestScanMessageType.success => Icons.check_circle_outline_rounded,
      _GuestScanMessageType.error => Icons.error_outline_rounded,
      _GuestScanMessageType.progress => Icons.search_rounded,
      _GuestScanMessageType.neutral => Icons.qr_code_scanner_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _message,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handling ? null : _showManualEntry,
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Enter Code'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              if (_awaitingRetry && !_handling) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _resetScanner,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _messageType == _GuestScanMessageType.error
                          ? 'Try Again'
                          : 'Scan again',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Guest access is view-only. Scanning never changes a plant record.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestScannerOverlay extends StatelessWidget {
  const _GuestScannerOverlay();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(220.0, 290.0).toDouble();
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 12),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.onEnterCode});

  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.scannerBackground,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 14),
            const Text(
              'Camera Unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow camera access in your device settings, or enter the EcoTag code instead.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onEnterCode,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Enter Code'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuestCodeEntryDialog extends StatefulWidget {
  const _GuestCodeEntryDialog();
  @override
  State<_GuestCodeEntryDialog> createState() => _GuestCodeEntryDialogState();
}

class _GuestCodeEntryDialogState extends State<_GuestCodeEntryDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Enter EcoTag Code'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
      decoration: const InputDecoration(
        labelText: 'EcoTag Code',
        hintText: 'Example: ECOTAG-202610-000001',
        prefixIcon: Icon(Icons.qr_code_rounded),
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('View Plant'),
      ),
    ],
  );
}
