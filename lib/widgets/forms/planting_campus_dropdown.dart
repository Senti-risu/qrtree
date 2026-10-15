import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Planting campus / outside campus',
      helperText:
          'Where this plant is physically planted. Your managing college stays the same.',
      helperMaxLines: 3,
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
  );
}
