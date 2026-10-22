import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_filter_sheet.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets('filter sheet fits $size / $scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 'all';
      var applied = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppFilterSheet<void>(
                  context,
                  builder: (sheetContext) => StatefulBuilder(
                    builder: (context, setState) => AppFilterSheet(
                      title: 'Filter Accounts',
                      subtitle: 'Narrow results',
                      applyLabel: 'Apply Filters',
                      onReset: () => setState(() => selected = 'all'),
                      onApply: () {
                        applied = true;
                        Navigator.pop(sheetContext);
                      },
                      child: AppFilterSection(
                        label: 'Role',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value in ['all', 'campus', 'college'])
                              AppFilterChip(
                                label: value,
                                selected: selected == value,
                                onSelected: () =>
                                    setState(() => selected = value),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Filter Accounts'), findsOneWidget);
      expect(find.text('Narrow results'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('campus'));
      await tester.pump();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(applied, isTrue);
      expect(selected, 'campus');
    });
  }
}
