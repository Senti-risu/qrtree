import 'package:flutter/material.dart';

/// Optional reference information, kept off the main generation form.
class QrNumberingInfo extends StatelessWidget {
  const QrNumberingInfo({super.key});

  static const explanation =
      'Format: ECOTAG-YYYYMM-000001. YYYYMM is the creation month and year; the last number starts at 1 and continues globally without resetting.';

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('QR Code Format'),
        content: const Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
    icon: const Icon(Icons.info_outline_rounded, size: 20),
    label: const Text('QR Code Format'),
  );
}
