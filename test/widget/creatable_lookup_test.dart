import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/forms/app_searchable_dropdown.dart';
import 'package:flutter_application_1/widgets/forms/creatable_lookup_input.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('missing values are explicitly added, normalized and selected', (
    tester,
  ) async {
    String? selected;
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => AppSearchableDropdown(
              label: 'Campus',
              value: selected,
              items: const ['Centro'],
              onChanged: (value) => update(() => selected = value),
              onCreate: (name) async {
                created = name;
                return name;
              },
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  san   jose  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add "san   jose"'));
    await tester.pumpAndSettle();
    expect(created, 'San Jose');
    expect(selected, 'San Jose');
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing invalidates old selection without erasing typed name', (
    tester,
  ) async {
    String? selected = 'Centro';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => AppSearchableDropdown(
              label: 'Campus',
              value: selected,
              items: const ['Centro'],
              onChanged: (value) => update(() => selected = value),
              onCreate: (name) async => name,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'New campus');
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'New campus',
    );
  });

  testWidgets('existing and locked campuses cannot be added again', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSearchableDropdown(
            label: 'Campus',
            value: null,
            items: const ['CSU Lasam'],
            disabledItems: const {'CSU Lasam'},
            onChanged: (_) {},
            onCreate: (name) async => name,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'csu lasam');
    await tester.pumpAndSettle();
    expect(find.textContaining('Add "'), findsNothing);
    final menu = tester.widget<DropdownMenu<String>>(
      find.byType(DropdownMenu<String>),
    );
    expect(menu.dropdownMenuEntries.single.enabled, isFalse);
  });

  testWidgets('failed creation stays unselected and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CreatableLookupInput(
            label: 'Campus',
            value: null,
            items: const [],
            onChanged: (value) => selected = value,
            onCreate: (name) async {
              attempts++;
              if (attempts == 1) throw Exception('network unavailable');
              return name;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Centro 2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add "Centro 2"'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(
      find.textContaining('Check your internet connection'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add "Centro 2"'));
    await tester.pumpAndSettle();
    expect(selected, 'Centro 2');
  });

  testWidgets('repeated taps create only once while saving', (tester) async {
    final pending = Completer<String?>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CreatableLookupInput(
            label: 'Campus',
            value: null,
            items: const [],
            onChanged: (_) {},
            onCreate: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'New Campus');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add "New Campus"'));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    pending.complete('New Campus');
    await tester.pumpAndSettle();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('empty-list campus is editable on narrow phone / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AppSearchableDropdown(
                label: 'Campus',
                value: null,
                items: const [],
                onChanged: (_) {},
                onCreate: (name) async => name,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'San Jose Del Norte');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add "San Jose Del Norte"'));
      await tester.tap(find.text('Add "San Jose Del Norte"'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
