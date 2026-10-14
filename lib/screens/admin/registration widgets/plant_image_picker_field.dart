import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';

class PlantImagePickerField extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageName;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const PlantImagePickerField({
    super.key,
    required this.imageBytes,
    required this.imageName,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Image',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: isPicking ? null : onPick,
          borderRadius: AppRadii.medium,
          child: Container(
            width: double.infinity,
            height: 180,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.medium,
              border: Border.all(color: AppColors.border),
            ),
            child: hasImage
                ? _ImagePreview(
                    imageBytes: imageBytes!,
                    onPick: onPick,
                    onRemove: onRemove,
                  )
                : _EmptyImageState(isPicking: isPicking),
          ),
        ),
        if (imageName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            imageName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List imageBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePreview({
    required this.imageBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(imageBytes, fit: BoxFit.cover),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Row(
            children: [
              _ImageActionButton(
                tooltip: 'Change image',
                icon: Icons.edit_outlined,
                onPressed: onPick,
              ),
              const SizedBox(width: AppSpacing.sm),
              _ImageActionButton(
                tooltip: 'Remove image',
                icon: Icons.delete_outline,
                iconColor: AppColors.danger,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _ImageActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.small,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
      ),
    );
  }
}

class _EmptyImageState extends StatelessWidget {
  final bool isPicking;

  const _EmptyImageState({required this.isPicking});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isPicking
            ? const CircularProgressIndicator()
            : const Icon(
                Icons.image_outlined,
                size: 44,
                color: AppColors.textSecondary,
              ),
        const SizedBox(height: AppSpacing.md),
        Text(
          isPicking ? 'Opening gallery...' : 'Click to upload image',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'PNG, JPG or JPEG',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
