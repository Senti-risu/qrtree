import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

class AccountStatusButton extends StatelessWidget {
  final bool active;
  final bool busy;
  final VoidCallback onPressed;

  const AccountStatusButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: active ? 'Deactivate account' : 'Activate account',
    child: OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? AppColors.green : AppColors.danger,
        backgroundColor: active
            ? AppColors.primaryContainer
            : AppColors.dangerContainer,
        side: BorderSide(
          color: (active ? AppColors.green : AppColors.danger).withValues(
            alpha: 0.18,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.circle, size: 8),
      label: Text(active ? 'Active' : 'Inactive'),
    ),
  );
}

class AccountRowActions extends StatelessWidget {
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const AccountRowActions({
    super.key,
    required this.onEdit,
    required this.onArchive,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : onEdit,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.edit_outlined, size: 19),
        label: const Text('Edit'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : onArchive,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: .4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.archive_outlined, size: 19),
        label: const Text('Archive'),
      ),
    ],
  );
}

/// Account identity above wrapping controls, shared by all mobile account lists.
class AccountAccessTile extends StatelessWidget {
  final String username;
  final String subtitle;
  final Widget statusButton;
  final Widget actions;

  const AccountAccessTile({
    super.key,
    required this.username,
    required this.subtitle,
    required this.statusButton,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                username.isEmpty ? '?' : username[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [statusButton, actions],
        ),
      ],
    ),
  );
}
