import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'media_preview.dart';

/// The displayed QR payload is the existing label, never a newly generated code.
class PlantEcoTagHeader extends StatelessWidget {
  const PlantEcoTagHeader({super.key, this.code});
  final String? code;

  @override
  Widget build(BuildContext context) {
    final value = code?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inline =
                constraints.maxWidth >= 560 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6;
            final copy = TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('EcoTag code copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy Code'),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (value.isNotEmpty)
                  InkWell(
                    onTap: () => showQrDetails(context, code: value),
                    child: Tooltip(
                      message: 'View QR details',
                      child: QrImageView(
                        data: value,
                        version: QrVersions.auto,
                        size: 72,
                        backgroundColor: Colors.white,
                        semanticsLabel: 'EcoTag QR code',
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.textSecondary,
                      size: 40,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EcoTag Code',
                        style: TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: AppTypography.label,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        value.isEmpty ? 'No EcoTag assigned' : value,
                        style: const TextStyle(
                          fontSize: AppTypography.body,
                          letterSpacing: 0,
                          wordSpacing: 0,
                        ),
                      ),
                      if (value.isNotEmpty && !inline) copy,
                    ],
                  ),
                ),
                if (value.isNotEmpty && inline) ...[
                  const SizedBox(width: 12),
                  copy,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
