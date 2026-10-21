import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/word_capitalization.dart';
import 'package:flutter_application_1/widgets/forms/app_text_field.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'registration_draft_flow_test.dart' as fixture;

class LowercaseLookupService extends fixture.LookupService {
  @override
  Future<List<Map<String, dynamic>>> getClassifications() async => [
    {
      'classification_id': 7,
      'plant_type': 'tree',
      'common_name': 'mango tree',
      'scientific_name': 'Mangifera indica',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getTowns() async => [
    {'town_id': 3, 'town_name': 'santa maria', 'zip_code': '3524'},
  ];
}

void main() {
  test('lookup names capitalize without changing IDs or scientific names', () {
    final result = capitalizeLookupNames({
      'classification_id': 7,
      'common_name': 'indian mango',
      'plant_type': 'tree',
      'scientific_name': 'Mangifera indica',
      'campus_name': 'CSU lasam',
      'status': 'assigned',
    });
    expect(result['common_name'], 'Indian Mango');
    expect(result['plant_type'], 'Tree');
    expect(result['campus_name'], 'CSU Lasam');
    expect(result['scientific_name'], 'Mangifera indica');
    expect(result['classification_id'], 7);
    expect(result['status'], 'assigned');
  });

  testWidgets(
    'selected database text displays capitals and retains its value',
    (tester) async {
      String? selected = 'santa maria';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => AppSearchableDropdown(
                label: 'Town',
                value: selected,
                items: const ['santa maria', 'san jose'],
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Santa Maria',
      );
      expect(selected, 'santa maria');
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('San Jose').last);
      await tester.pumpAndSettle();
      expect(selected, 'san jose');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'San Jose',
      );
    },
  );

  test(
    'capitalizes initials while preserving name casing, acronyms and spacing',
    () {
      expect(capitalizeWords('juan dela cruz'), 'Juan Dela Cruz');
      expect(capitalizeWords('  indian   mango '), '  Indian   Mango ');
      expect(capitalizeWords("o'neil santo-domingo"), "O'Neil Santo-Domingo");
      expect(capitalizeWords('ñarra café'), 'Ñarra Café');
      expect(capitalizeWords('CSU McDonald Jr.'), 'CSU McDonald Jr.');
      expect(capitalizeWords(''), '');
    },
  );

  test('formatter handles typing and pasting without moving the cursor', () {
    const formatter = WordCapitalizationFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'juan dela cruz',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(result.text, 'Juan Dela Cruz');
    expect(result.selection.baseOffset, 5);
  });

  test('formatter leaves unfinished keyboard composition alone', () {
    const value = TextEditingValue(
      text: 'ñarra',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    expect(
      const WordCapitalizationFormatter().formatEditUpdate(
        TextEditingValue.empty,
        value,
      ),
      value,
    );
  });

  testWidgets(
    'registration saves catalog variety and capitalizes planter drafts',
    (tester) async {
      final drafts = fixture.MemoryDrafts();
      await fixture.open(tester, drafts, width: 1600);
      AppSearchableDropdown dropdown(String label) =>
          tester.widget<AppSearchableDropdown>(
            find.byWidgetPredicate(
              (w) => w is AppSearchableDropdown && w.label == label,
            ),
          );
      dropdown('Plant Type').onChanged('Tree');
      await tester.pumpAndSettle();
      dropdown('Common Name').onChanged('Mango');
      await tester.pumpAndSettle();
      dropdown('Variety (Optional)').onChanged('Native');
      await tester.pumpAndSettle();
      final planter = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'Tree Planter (Optional)',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(planter);
      await tester.enterText(planter, 'juan dela cruz');
      await tester.pumpAndSettle();
      expect(find.text('Native'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      final save = find.byKey(const Key('save-registration-draft'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(drafts.value?['variety'], 'Native');
      expect(drafts.value?['planter'], 'Juan Dela Cruz');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lookup names are capitalized without changing IDs or scientific names',
    (tester) async {
      final drafts = fixture.MemoryDrafts();
      await fixture.open(
        tester,
        drafts,
        width: 1600,
        service: LowercaseLookupService(),
      );
      AppSearchableDropdown field(String label) =>
          tester.widget<AppSearchableDropdown>(
            find.byWidgetPredicate(
              (w) => w is AppSearchableDropdown && w.label == label,
            ),
          );
      field('Plant Type').onChanged('Tree');
      await tester.pumpAndSettle();
      expect(field('Town').items, ['Santa Maria']);
      field('Common Name').onChanged('Mango Tree');
      await tester.pumpAndSettle();
      final scientific = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'Scientific Name',
        ),
      );
      expect(scientific.controller.text, 'Mangifera indica');
      expect(scientific.inputFormatters, isNull);
      await tester.tap(find.byKey(const Key('save-registration-draft')));
      await tester.pumpAndSettle();
      expect(drafts.value?['classificationId'], 7);
      expect(tester.takeException(), isNull);
    },
  );
}
