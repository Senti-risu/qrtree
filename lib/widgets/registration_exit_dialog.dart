import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

class RegistrationExitDialog extends StatelessWidget {
  const RegistrationExitDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    constraints: const BoxConstraints(maxWidth: 420),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
    scrollable: true,
    titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    title: Text(
      'Leave this registration?',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkGreen,
      ),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save your draft or discard your changes.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'save'),
          icon: const Icon(Icons.save_outlined, size: 20),
          label: const Text('Save draft'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'discard'),
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          label: const Text('Discard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: .5)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, 'stay'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Stay'),
        ),
      ],
    ),
  );
}
