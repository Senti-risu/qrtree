import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';

class AppSearchableDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String hintText;

  const AppSearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.hintText = 'Type or select',
  });

  @override
  Widget build(BuildContext context) {
    final validValue = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              key: ValueKey('$label-$validValue-${items.length}-$enabled'),
              width: constraints.maxWidth,
              initialSelection: validValue,
              hintText: hintText,
              enabled: enabled,
              menuHeight: 280,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              selectedTrailingIcon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.green,
              ),
              dropdownMenuEntries: items
                  .map(
                    (item) =>
                        DropdownMenuEntry<String>(value: item, label: item),
                  )
                  .toList(),
              onSelected: enabled ? onChanged : null,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: enabled
                    ? AppColors.surface
                    : AppColors.surfaceDisabled,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.medium,
                  borderSide: AppBorders.subtleSide,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppRadii.medium,
                  borderSide: AppBorders.subtleSide,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: AppRadii.medium,
                  borderSide: AppBorders.focusedSide,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
