import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'registration_draft_flow_test.dart' as fixture;

void main() {
  testWidgets(
    'editing a selected name clears its value but preserves search text',
    (tester) async {
      String? selected = 'Lasam';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => AppSearchableDropdown(
                label: 'Town',
                value: selected,
                items: const ['Lasam', 'Piat'],
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Piat');
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Piat',
      );
      expect(find.textContaining('Add "'), findsNothing);
      await tester.tap(find.text('Piat').last);
      await tester.pumpAndSettle();
      expect(selected, 'Piat');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing Town text clears both location IDs from saved draft', (
    tester,
  ) async {
    final drafts = fixture.MemoryDrafts();
    await fixture.open(tester, drafts, width: 1600);
    AppSearchableDropdown field(String label) =>
        tester.widget<AppSearchableDropdown>(
          find.byWidgetPredicate(
            (w) => w is AppSearchableDropdown && w.label == label,
          ),
        );
    field('Town').onChanged('Lasam');
    await tester.pumpAndSettle();
    field('Barangay').onChanged('Centro');
    await tester.pumpAndSettle();
    final town = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is AppSearchableDropdown && w.label == 'Town',
      ),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(town);
    await tester.enterText(town, 'Piat');
    await tester.pumpAndSettle();
    expect(field('Town').value, isNull);
    expect(field('Barangay').value, isNull);
    expect(field('Barangay').enabled, isFalse);
    final save = find.byKey(const Key('save-registration-draft'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(drafts.value!['townId'], isNull);
    expect(drafts.value!['barangayId'], isNull);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'Growth Stage': 'growthId',
    'Health Status': 'healthId',
  }.entries) {
    testWidgets('clearing ${entry.key} clears its registration ID', (
      tester,
    ) async {
      final drafts = fixture.MemoryDrafts();
      await fixture.open(tester, drafts, width: 1600);
      AppSearchableDropdown field(String label) =>
          tester.widget<AppSearchableDropdown>(
            find.byWidgetPredicate(
              (w) => w is AppSearchableDropdown && w.label == label,
            ),
          );
      field('Plant Type').onChanged('Tree');
      await tester.pumpAndSettle();
      field('Common Name').onChanged('Mango');
      field('Growth Stage').onChanged('Seedling');
      field('Health Status').onChanged('Healthy');
      await tester.pumpAndSettle();
      field(entry.key).onChanged(null);
      await tester.pumpAndSettle();
      expect(field(entry.key).value, isNull);
      final save = find.byKey(const Key('save-registration-draft'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(drafts.value![entry.value], isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('typing Common Name clears any previous classification ID', (
    tester,
  ) async {
    final drafts = fixture.MemoryDrafts()
      ..value = {
        'classificationId': 7,
        'growthId': 5,
        'healthId': 6,
        'townId': 3,
        'barangayId': 4,
        'plantingCampus': '1',
        'datePlanted': '2026-01-01',
      };
    await fixture.open(tester, drafts, width: 1600);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final commonName = find.byWidgetPredicate(
      (widget) =>
          widget is AppSearchableDropdown && widget.label == 'Common Name',
    );
    final input = find.descendant(
      of: commonName,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Unknown tree');
    await tester.pumpAndSettle();
    expect(find.text('Add "Unknown tree"'), findsNothing);
    final save = find.byKey(const Key('save-registration-draft'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(drafts.value!['classificationId'], isNull);
    expect(drafts.value!['commonName'], 'Unknown Tree');
    expect(tester.takeException(), isNull);
  });

  testWidgets('common names are filtered by the selected plant type', (
    tester,
  ) async {
    await fixture.open(tester, fixture.MemoryDrafts(), width: 1600);
    AppSearchableDropdown field(String label) =>
        tester.widget<AppSearchableDropdown>(
          find.byWidgetPredicate(
            (w) => w is AppSearchableDropdown && w.label == label,
          ),
        );

    field('Plant Type').onChanged('Tree');
    await tester.pumpAndSettle();
    expect(field('Common Name').items, ['Mango']);

    field('Plant Type').onChanged('Herb');
    await tester.pumpAndSettle();
    expect(field('Common Name').items, isEmpty);
    expect(field('Common Name').value, isNull);
    expect(tester.takeException(), isNull);
  });
}
