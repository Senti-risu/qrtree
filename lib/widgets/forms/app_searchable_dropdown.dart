import 'package:flutter/material.dart';

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

  static const Color _green = Color(0xFF168B47);
  static const Color _darkGreen = Color(0xFF075E38);
  static const Color _borderColor = Color(0xFFDCE8DF);

  @override
  Widget build(BuildContext context) {
    final validValue = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _darkGreen,
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
                color: _green,
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
                fillColor: enabled ? Colors.white : const Color(0xFFF0F2F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
