import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Physical planting location; deliberately independent of account ownership.
class PlantingCampusDropdown extends StatelessWidget {
  const PlantingCampusDropdown({
    super.key,
    required this.campuses,
    required this.value,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> campuses;
  final String? value;
  final ValueChanged<String?>? onChanged;

  static const outside = 'outside';
  static int? campusId(String? value) =>
      value == outside ? null : int.tryParse(value ?? '');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Planting campus',
        style: TextStyle(
          color: AppColors.darkGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        hint: const Text(
          'Select campus or Outside campus',
          style: TextStyle(fontSize: 14),
        ),
        decoration: const InputDecoration(
          helperText: 'Select a CSU campus or Outside campus.',
          helperMaxLines: 2,
        ),
        items: [
          const DropdownMenuItem(value: outside, child: Text('Outside campus')),
          for (final campus in campuses)
            DropdownMenuItem(
              value: '${campus['campus_id']}',
              child: Text(
                '${campus['campus_name']}',
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
