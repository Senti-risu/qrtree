import 'package:flutter/services.dart';

/// Uppercases word initials without damaging acronyms or existing name casing.
String capitalizeWords(String text) => text.replaceAllMapped(
  RegExp(r"(^|[\s\-'’])(\p{L})", unicode: true),
  (match) => '${match[1]}${match[2]!.toUpperCase()}',
);

/// Lookup display names only; scientific names and machine values are excluded.
Map<String, dynamic> capitalizeLookupNames(Map<String, dynamic> row) => {
  for (final entry in row.entries)
    entry.key:
        const {
              'common_name',
              'plant_type',
              'campus_name',
              'college_name',
              'town_name',
              'barangay_name',
              'growth_stage',
              'status_name',
            }.contains(entry.key) &&
            entry.value is String
        ? capitalizeWords(entry.value as String)
        : entry.value,
};

class WordCapitalizationFormatter extends TextInputFormatter {
  const WordCapitalizationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Let keyboards finish composing accented/IME input before formatting it.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final text = capitalizeWords(newValue.text);
    if (text == newValue.text) return newValue;
    int offset(int value) => value < 0
        ? value
        : capitalizeWords(
            newValue.text.substring(0, value.clamp(0, newValue.text.length)),
          ).length;
    return newValue.copyWith(
      text: text,
      selection: newValue.selection.copyWith(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}
