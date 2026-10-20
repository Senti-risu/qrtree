import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/search_match.dart';

void main() {
  test('letters narrow results immediately by word prefix', () {
    const plants = ['Mango', 'Mahogany', 'Apple', 'Guava'];
    List<String> search(String query) =>
        plants.where((plant) => matchesWordPrefixes([plant], query)).toList();
    expect(search('m'), ['Mango', 'Mahogany']);
    expect(search('man'), ['Mango']);
    expect(search('MANGO'), ['Mango']);
    expect(search('ang'), isEmpty);
    expect(search(''), plants);
    expect(search('xyz'), isEmpty);
  });

  test('matches later words, multiple fields, IDs and punctuation', () {
    const values = ['Red Mango', 'CSU Lasam', 'inspect_acc', 27, null];
    expect(matchesWordPrefixes(values, 'm'), isTrue);
    expect(matchesWordPrefixes(values, '  MAN las  '), isTrue);
    expect(matchesWordPrefixes(values, 'acc'), isTrue);
    expect(matchesWordPrefixes(values, '27'), isTrue);
    expect(matchesWordPrefixes(values, 'm apple'), isFalse);
  });

  test('supports QR codes, usernames, and literal special characters', () {
    expect(
      matchesWordPrefixes(['ECOTAG-202610-000025'], 'ecotag-202610-000025'),
      isTrue,
    );
    expect(matchesWordPrefixes(['ECOTAG-202610-000025'], '00002'), isTrue);
    expect(matchesWordPrefixes(['inspect_acc'], 'inspect_acc'), isTrue);
    expect(matchesWordPrefixes(['Mango'], '%m'), isTrue);
    expect(matchesWordPrefixes(['Apple'], '%m'), isFalse);
  });
}
