import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../widgets/app_card.dart';
import 'registration_form_fields.dart';

class PlantLocationCard extends StatelessWidget {
  final String? college;
  final String? campus;
  final String? town;
  final String? barangay;

  final List<String> colleges;
  final List<String> campuses;
  final List<String> towns;
  final List<String> barangays;

  final TextEditingController zipCodeController;

  final ValueChanged<String?> onCollegeChanged;
  final ValueChanged<String?> onCampusChanged;
  final ValueChanged<String?> onTownChanged;
  final ValueChanged<String?> onBarangayChanged;

  final bool saving;
  final VoidCallback onSave;

  const PlantLocationCard({
    super.key,
    required this.college,
    required this.campus,
    required this.town,
    required this.barangay,
    required this.colleges,
    required this.campuses,
    required this.towns,
    required this.barangays,
    required this.zipCodeController,
    required this.onCollegeChanged,
    required this.onCampusChanged,
    required this.onTownChanged,
    required this.onBarangayChanged,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Campus is selected first.
          RegistrationDropdownField(
            label: 'Campus',
            value: campus,
            items: campuses,
            onChanged: onCampusChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          RegistrationDropdownField(
            label: 'College',
            value: college,
            items: colleges,
            onChanged: onCollegeChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          RegistrationDropdownField(
            label: 'Town',
            value: town,
            items: towns,
            onChanged: onTownChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          RegistrationDropdownField(
            label: 'Barangay',
            value: barangay,
            items: barangays,
            onChanged: onBarangayChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: 150,
            child: RegistrationTextField(
              label: 'Zip code',
              controller: zipCodeController,
              readOnly: true,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 140,
              height: 50,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
