import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import '../../utils/word_capitalization.dart';

/// Physical planting location; deliberately independent of account ownership.
class PlantingCampusDropdown extends StatelessWidget {
  const PlantingCampusDropdown({
    super.key,
    required this.campuses,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.isRequired = false,
    this.showHelperText = true,
  });
  final List<Map<String, dynamic>> campuses;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? errorText;
  final bool isRequired;
  final bool showHelperText;

  static const outside = 'outside';
  static int? campusId(String? value) =>
      value == outside ? null : int.tryParse(value ?? '');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isRequired ? 'Planting Campus *' : 'Planting Campus',
        style: const TextStyle(
          color: AppColors.darkGreen,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        style: const TextStyle(
          fontSize: AppTypography.body,
          color: AppColors.textPrimary,
        ),
        hint: const Text(
          'Select Campus Or Outside Campus',
          style: TextStyle(fontSize: AppTypography.body),
        ),
        decoration: InputDecoration(
          errorText: errorText,
          errorMaxLines: 3,
          helperText: showHelperText
              ? 'Select a CSU campus or Outside campus.'
              : null,
          helperMaxLines: 2,
        ),
        items: [
          const DropdownMenuItem(value: outside, child: Text('Outside Campus')),
          for (final campus in campuses)
            DropdownMenuItem(
              value: '${campus['campus_id']}',
              child: Text(
                capitalizeWords('${campus['campus_name']}'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
        validator: (choice) =>
            choice == null ? 'Select a campus or Outside campus.' : null,
      ),
    ],
  );
}
