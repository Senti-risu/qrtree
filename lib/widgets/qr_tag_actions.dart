import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Explicit actions without allowing arbitrary QR lifecycle transitions.
class QrTagActions extends StatelessWidget {
  final String status;
  final bool busy;
  final VoidCallback? onPrint;
  final VoidCallback onMarkDamaged;
  final VoidCallback onReplace;
  final VoidCallback onRetire;

  const QrTagActions({
    super.key,
    required this.status,
    required this.onPrint,
    required this.onMarkDamaged,
    required this.onReplace,
    required this.onRetire,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = status.trim().toLowerCase();
    final action = switch (value) {
      'assigned' => (
        Icons.broken_image_outlined,
        'Mark damaged',
        onMarkDamaged,
        AppColors.warning,
      ),
      'damaged' => (
        Icons.swap_horiz_rounded,
        'Replace label',
        onReplace,
        AppColors.green,
      ),
      'available' => (
        Icons.archive_outlined,
        'Retire label',
        onRetire,
        AppColors.danger,
      ),
      _ => null,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : onPrint,
          icon: const Icon(Icons.print_outlined, size: 19),
          label: const Text('Print'),
        ),
        if (action != null)
          OutlinedButton.icon(
            onPressed: busy ? null : action.$3,
            style: OutlinedButton.styleFrom(
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
          )
        else
          const Tooltip(
            message: 'This label has reached a final lifecycle state',
            child: Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
