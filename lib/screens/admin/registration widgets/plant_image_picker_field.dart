import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Image',
          style: TextStyle(
            color: AppColors.darkGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isPicking ? null : onPick,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            height: 180,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB8C8BC), width: 1.2),
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
          const SizedBox(height: 8),
          Text(
            imageName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.green, fontSize: 10),
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
          top: 10,
          right: 10,
          child: Row(
            children: [
              _ImageActionButton(
                tooltip: 'Change image',
                icon: Icons.edit_outlined,
                onPressed: onPick,
              ),
              const SizedBox(width: 8),
              _ImageActionButton(
                tooltip: 'Remove image',
                icon: Icons.delete_outline,
                iconColor: Colors.red,
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
    this.iconColor = AppColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
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
            ? const CircularProgressIndicator(color: AppColors.green)
            : const Icon(
                Icons.image_outlined,
                size: 44,
                color: Color(0xFF8D9990),
              ),
        const SizedBox(height: 10),
        Text(
          isPicking ? 'Opening gallery...' : 'Click to upload image',
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'PNG, JPG or JPEG',
          style: TextStyle(color: Color(0xFF879188), fontSize: 10),
        ),
      ],
    );
  }
}
