import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import 'plant_image_picker_field.dart';
import 'registration_form_fields.dart';

class PlantClassificationCard extends StatelessWidget {
  final String? plantType;
  final String? commonName;
  final String? growthStage;
  final String? healthStatus;
  final DateTime? datePlanted;

  final List<String> plantTypes;
  final List<String> commonNames;
  final List<String> growthStages;
  final List<String> healthStatuses;

  final TextEditingController varietyController;
  final TextEditingController scientificNameController;
  final TextEditingController planterController;

  final ValueChanged<String?> onPlantTypeChanged;
  final ValueChanged<String?> onCommonNameChanged;
  final ValueChanged<String?> onGrowthStageChanged;
  final ValueChanged<String?> onHealthStatusChanged;
  final VoidCallback onDateTap;

  final Uint8List? imageBytes;
  final String? imageName;
  final bool isPickingImage;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const PlantClassificationCard({
    super.key,
    required this.plantType,
    required this.commonName,
    required this.growthStage,
    required this.healthStatus,
    required this.datePlanted,
    required this.plantTypes,
    required this.commonNames,
    required this.growthStages,
    required this.healthStatuses,
    required this.varietyController,
    required this.scientificNameController,
    required this.planterController,
    required this.onPlantTypeChanged,
    required this.onCommonNameChanged,
    required this.onGrowthStageChanged,
    required this.onHealthStatusChanged,
    required this.onDateTap,
    required this.imageBytes,
    required this.imageName,
    required this.isPickingImage,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plant Classification',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),

          ResponsiveFieldPair(
            first: RegistrationDropdownField(
              label: 'Plant Type',
              value: plantType,
              items: plantTypes,
              onChanged: onPlantTypeChanged,
            ),
            second: RegistrationDropdownField(
              label: 'Common Name',
              value: commonName,
              items: commonNames,
              onChanged: onCommonNameChanged,
            ),
          ),

          const SizedBox(height: 16),

          ResponsiveFieldPair(
            first: RegistrationTextField(
              label: 'Variety',
              controller: varietyController,
              hint: 'Enter variety',
            ),
            second: RegistrationTextField(
              label: 'Scientific Name',
              controller: scientificNameController,
              readOnly: true,
            ),
          ),

          const SizedBox(height: 16),

          ResponsiveFieldPair(
            first: RegistrationDropdownField(
              label: 'Growth Stage',
              value: growthStage,
              items: growthStages,
              onChanged: onGrowthStageChanged,
            ),
            second: RegistrationDropdownField(
              label: 'Health Status',
              value: healthStatus,
              items: healthStatuses,
              onChanged: onHealthStatusChanged,
            ),
          ),

          const SizedBox(height: 16),

          ResponsiveFieldPair(
            first: RegistrationDateField(value: datePlanted, onTap: onDateTap),
            second: RegistrationTextField(
              label: 'Tree planter (optional)',
              controller: planterController,
            ),
          ),

          const SizedBox(height: 20),

          PlantImagePickerField(
            imageBytes: imageBytes,
            imageName: imageName,
            isPicking: isPickingImage,
            onPick: onPickImage,
            onRemove: onRemoveImage,
          ),
        ],
      ),
    );
  }
}
