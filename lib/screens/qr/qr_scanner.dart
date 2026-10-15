import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/qr_service.dart';
import '../../models/app_role.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import '../admin/register_plants.dart';
import '../plants/plant_detail_screen.dart';

enum _ScanMessageType { neutral, progress, success, error }

class QrScannerScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const QrScannerScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final QrService _qrService = QrService();
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;
  String _message =
      'Place an EcoTag label inside the frame. You can also enter its code manually.';
  _ScanMessageType _messageType = _ScanMessageType.neutral;
  String? _lastCode;
  DateTime? _lastScanAt;

  Future<void> _handleCode(String rawCode) async {
    final code = rawCode.trim();
    if (_handling || code.isEmpty) return;
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
      _message = 'Checking this EcoTag…';
      _messageType = _ScanMessageType.progress;
    });

    try {
      final tag = await _qrService.findQrTag(code);
      if (!mounted) return;

      if (tag == null) {
        HapticFeedback.vibrate();
        setState(() {
          _handling = false;
          _message = 'This is not a recognized EcoTag. Try another label.';
          _messageType = _ScanMessageType.error;
        });
        return;
      }

      await HapticFeedback.mediumImpact();
      final status = QrService.statusOf(tag);

      if (status == 'available') {
        if (!RoleCapabilities.fromValue(widget.role).canRegisterPlants) {
          setState(() {
            _handling = false;
            _message =
                'This label is available but has not been assigned to a plant. Ask a College Admin to register it.';
            _messageType = _ScanMessageType.neutral;
          });
          return;
        }
        await _controller.stop();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterPlantScreen(
              userId: widget.userId,
              username: widget.username,
              role: widget.role,
              campusId: widget.campusId,
              collegeId: widget.collegeId,
              existingQrTag: tag,
            ),
          ),
        );
        return;
      }

      if (status == 'assigned') {
        final rawTagId = tag['qr_tag_id'];
        final tagId = rawTagId is int
            ? rawTagId
            : int.tryParse(rawTagId?.toString() ?? '');
        if (tagId == null) {
          setState(() {
            _handling = false;
            _message =
                'This label is missing its record number. Contact an administrator.';
            _messageType = _ScanMessageType.error;
          });
          return;
        }
        final plantId = await _qrService.getAssignedPlantId(tagId);
        if (!mounted) return;
        if (plantId == null) {
          setState(() {
            _handling = false;
            _message =
                'This label is assigned, but its plant record could not be found. Contact an administrator.';
            _messageType = _ScanMessageType.error;
          });
          return;
        }
        await _controller.stop();
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(
              plantId: plantId,
              userId: widget.userId,
              username: widget.username,
              role: widget.role,
            ),
          ),
        );
        if (!mounted) return;
        await _controller.start();
        setState(() {
          _handling = false;
          _message = 'Ready to scan another EcoTag label.';
          _messageType = _ScanMessageType.success;
          _lastCode = null;
        });
        return;
      }

      if (status == 'damaged') {
        setState(() {
          _handling = false;
          _message =
              'This label was reported damaged. A College Admin needs to replace it before the plant can be opened by scanning.';
          _messageType = _ScanMessageType.error;
        });
        return;
      }

      if (status == 'replaced') {
        final replacementId = tag['replacement_qr_tag_id'];
        setState(() {
          _handling = false;
          _message = replacementId == null
              ? 'This label has been replaced. Scan the newer label attached to the plant.'
              : 'This label has been replaced by QR #$replacementId. Scan the newer label attached to the plant.';
          _messageType = _ScanMessageType.neutral;
        });
        return;
      }

      if (status == 'retired') {
        setState(() {
          _handling = false;
          _message =
              'This label is retired and cannot be used again. Contact a College Admin if the plant needs a new label.';
          _messageType = _ScanMessageType.neutral;
        });
        return;
      }

      setState(() {
        _handling = false;
        _message =
            'This EcoTag is unavailable and cannot be used. Try another label.';
        _messageType = _ScanMessageType.error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _handling = false;
        _message = userFacingError(
          error,
          fallback: 'The label could not be checked. Please try again.',
        );
        _messageType = _ScanMessageType.error;
      });
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
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter EcoTag code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          decoration: const InputDecoration(
            labelText: 'QR code or tag ID',
            hintText: 'Example: ECOTAG-…',
            prefixIcon: Icon(Icons.qr_code_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Check code'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.isNotEmpty) await _handleCode(code);
  }

  void _resetScanner() {
    setState(() {
      _handling = false;
      _lastCode = null;
      _message = 'Place another EcoTag label inside the frame.';
      _messageType = _ScanMessageType.neutral;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
            tooltip: 'Toggle flashlight',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
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
                      onDetect: (capture) {
                        if (_handling) return;
                        for (final barcode in capture.barcodes) {
                          final value = barcode.rawValue;
                          if (value != null && value.isNotEmpty) {
                            _handleCode(value);
                            break;
                          }
                        }
                      },
                    ),
                    const _ScannerOverlay(),
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

  Widget _statusPanel() {
    final color = switch (_messageType) {
      _ScanMessageType.success => AppColors.green,
      _ScanMessageType.error => AppColors.danger,
      _ScanMessageType.progress => AppColors.green,
      _ScanMessageType.neutral => AppColors.textSecondary,
    };
    final icon = switch (_messageType) {
      _ScanMessageType.success => Icons.check_circle_outline_rounded,
      _ScanMessageType.error => Icons.error_outline_rounded,
      _ScanMessageType.progress => Icons.search_rounded,
      _ScanMessageType.neutral => Icons.qr_code_scanner_rounded,
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
                  label: const Text('Enter code'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              if (_messageType == _ScanMessageType.error) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _resetScanner,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

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
