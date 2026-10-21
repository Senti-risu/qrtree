import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Explicit actions without allowing arbitrary QR lifecycle transitions.
class QrTagActions extends StatelessWidget {
  final String status;
  final bool busy;
  final VoidCallback? onPrint;
  final VoidCallback onMarkDamaged;
  final VoidCallback? onView;

  const QrTagActions({
    super.key,
    required this.status,
    required this.onPrint,
    required this.onMarkDamaged,
    this.onView,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = status.trim().toLowerCase();
    final action = switch (value) {
      'assigned' => (
        Icons.broken_image_outlined,
        'Mark Damaged',
        onMarkDamaged,
        AppColors.warning,
      ),
      _ => null,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onView != null)
          OutlinedButton.icon(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.visibility_outlined, size: 19),
            label: const Text('View QR'),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : onPrint,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.print_outlined, size: 19),
          label: Text(value == 'damaged' ? 'Reprint QR' : 'Print QR'),
        ),
        if (action != null)
          OutlinedButton.icon(
            onPressed: busy ? null : action.$3,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              visualDensity: VisualDensity.compact,
              foregroundColor: action.$4,
              side: BorderSide(color: action.$4.withValues(alpha: .4)),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(action.$1, size: 19),
            label: Text(action.$2),
          ),
      ],
    );
  }
}
