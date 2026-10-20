/// Matches every typed word against the start of a word in the record.
bool matchesWordPrefixes(Iterable<Object?> values, String query) {
  final separator = RegExp(r'[\s\p{P}]+', unicode: true);
  final terms = query
      .trim()
      .toLowerCase()
      .split(separator)
      .where((term) => term.isNotEmpty);
  if (terms.isEmpty) return true;
  final words = values
      .whereType<Object>()
      .join(' ')
      .toLowerCase()
      .split(separator);
  return terms.every((term) => words.any((word) => word.startsWith(term)));
}
