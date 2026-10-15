import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/plant_details_presentation.dart';
import 'package:flutter_application_1/widgets/plant_detail_content.dart';

Widget detailContent(BuildContext context) => Scaffold(
  appBar: AppBar(
    title: const Text('Plant Details'),
    leading: IconButton(
      tooltip: 'Close plant details',
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context, 'closed'),
    ),
  ),
  body: ListView(
    children: [
      for (var i = 0; i < 20; i++)
        SizedBox(height: 100, child: Text('Detail $i')),
      const Text('Last detail'),
    ],
  ),
);

void main() {
  for (final scenario in [
    (size: const Size(1440, 900), web: true, floats: true),
    (size: const Size(390, 844), web: true, floats: false),
    (size: const Size(1000, 400), web: true, floats: false),
    (size: const Size(1440, 900), web: false, floats: false),
  ]) {
    testWidgets('details adapt at ${scenario.size}, web=${scenario.web}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await Navigator.push<String>(
                    context,
                    plantDetailsRoute<String>(
                      platformIsWeb: scenario.web,
                      builder: detailContent,
                    ),
                  );
                },
                child: const Text('Open plant'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open plant'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('floating-plant-details')),
        scenario.floats ? findsOneWidget : findsNothing,
      );
      if (scenario.floats) {
        final rect = tester.getRect(
          find.byKey(const ValueKey('floating-plant-details')),
        );
        expect(rect.width, lessThanOrEqualTo(1080));
        expect(rect.left, greaterThan(0));
        expect(rect.right, lessThan(scenario.size.width));
        expect(rect.height, lessThan(scenario.size.height));
      }
      await tester.scrollUntilVisible(
        find.text('Last detail'),
        350,
        maxScrolls: 20,
      );
      expect(find.text('Last detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close plant details'));
      await tester.pumpAndSettle();
      expect(find.text('Open plant'), findsOneWidget);
      expect(result, 'closed');
    });
  }

  testWidgets(
    'Escape closes floating details and resizing falls back to full screen',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  plantDetailsRoute(
                    platformIsWeb: true,
                    builder: detailContent,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'detail photo and long information remain readable on small screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  PlantDetailHero(
                    name: 'Mango',
                    scientificName: 'Mangifera indica',
                    plantId: '3',
                    imageUrl: '',
                  ),
                  PlantDetailFields(
                    title: 'Managed by',
                    rows: {
                      'Managing college':
                          'College of Information and Computing Sciences',
                      'Managing campus':
                          'Cagayan State University, Lasam Campus',
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ClipRRect)).height,
        lessThanOrEqualTo(240),
      );
      expect(
        find.text('College of Information and Computing Sciences'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
