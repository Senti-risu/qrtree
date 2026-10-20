import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/app_search_field.dart';
import 'package:flutter_application_1/widgets/app_workspace_page.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/compact_filter_panel.dart';

void main() {
  testWidgets('dropdown survives workspace rebuilds while typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => AppWorkspacePage(
              header: const AppPageHeader(
                title: 'Plant Records',
                subtitle: 'Browse plants',
              ),
              tools: CompactFilterPanel(
                search: AppSearchField(
                  controller: controller,
                  suggestions: ['Mango', 'Malus domestica'],
                  onChanged: (_) => update(() {}),
                  decoration: InputDecoration(
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                controls: [
                  if (controller.text.isNotEmpty)
                    TextButton(onPressed: () {}, child: const Text('Reset')),
                ],
                choices: const [],
                resultSummary: 'Plants',
              ),
              body: ListView(children: const [Text('Results')]),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Ma');
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ListTile, 'Mango').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 1100.0]) {
    testWidgets('suggestions filter and select at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var query = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchField(
                controller: controller,
                suggestions: const ['Mango', 'Mahogany', 'mango', 'Apple'],
                onChanged: (value) => query = value,
                decoration: const InputDecoration(hintText: 'Search'),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'm');
      await tester.pumpAndSettle();
      expect(query, 'm');
      expect(find.text('Mango'), findsOneWidget);
      expect(find.text('Mahogany'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('mango'), findsNothing);
      await tester.tap(find.text('Mango'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Mango');
      expect(query, 'Mango');
      expect(find.byType(ListTile), findsNothing);
      await tester.enterText(find.byType(TextField), 'maho');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(query, 'Mahogany');
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
