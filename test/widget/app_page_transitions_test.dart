import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_page_transitions.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  test('all platforms use the shared transition policy', () {
    final builders = AppTheme.light.pageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      expect(builders[platform], isA<AppPageTransitionsBuilder>());
    }
  });

  for (final reduced in [false, true]) {
    testWidgets('transition respects reduced motion: $reduced', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const AppPageTransition(
              animation: AlwaysStoppedAnimation(0.5),
              child: Text('Page content'),
            ),
          ),
        ),
      );
      final transition = find.byType(AppPageTransition);
      final fade = find.descendant(
        of: transition,
        matching: find.byType(FadeTransition),
      );
      expect(fade, reduced ? findsNothing : findsOneWidget);
      if (!reduced) {
        expect(
          tester.widget<FadeTransition>(fade).opacity.value,
          closeTo(Curves.easeOutCubic.transform(0.5), 0.001),
        );
      }
      expect(find.text('Page content'), findsOneWidget);
    });
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.iOS,
  ]) {
    testWidgets('push and back remain usable on $platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Return'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Next'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Return'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();
      expect(find.text('Next').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
