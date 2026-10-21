import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';

import '../../theme/app_colors.dart';
import 'creatable_lookup_input.dart';
import '../../utils/word_capitalization.dart';

class AppSearchableDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? searchText;
  final ValueChanged<String>? onSearchTextChanged;
  final bool enabled;
  final String hintText;
  final String? errorText;
  final bool isRequired;
  final Future<String?> Function(String)? onCreate;
  final Set<String> disabledItems;
  final bool allowCustomValue;

  const AppSearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.searchText,
    this.onSearchTextChanged,
    this.enabled = true,
    this.hintText = 'Type or select',
    this.errorText,
    this.isRequired = false,
    this.onCreate,
    this.disabledItems = const {},
    this.allowCustomValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final validValue = allowCustomValue || items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '${capitalizeWords(label)} *' : capitalizeWords(label),
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontSize: AppTypography.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        CreatableLookupInput(
          label: label,
          value: validValue,
          items: items,
          enabled: enabled,
          searchText: searchText,
          onSearchTextChanged: onSearchTextChanged,
          errorText: errorText,
          onChanged: onChanged,
          onCreate: onCreate,
          allowCustomValue: allowCustomValue,
          disabledItems: disabledItems,
          hintText: hintText,
        ),
      ],
    );
  }
}
