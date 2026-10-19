import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'registration_draft_flow_test.dart' as fixture;

void main() {
  for (final role in ['college_admin', 'inspection_team']) {
    for (final width in [320.0, 768.0, 1100.0, 1600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'registration header contains draft action $role / $width / $scale',
          (tester) async {
            await fixture.open(
              tester,
              fixture.MemoryDrafts(),
              width: width,
              scale: scale,
              role: role,
            );
            final save = find.byKey(const Key('save-registration-draft'));
            final header = find.byKey(
              Key(
                width >= 900
                    ? 'registration-page-header'
                    : 'registration-step-header',
              ),
            );
            expect(save, findsOneWidget);
            expect(find.descendant(of: header, matching: save), findsOneWidget);
            final headerRect = tester.getRect(header);
            final saveRect = tester.getRect(save);
            expect(headerRect.contains(saveRect.topLeft), isTrue);
            expect(headerRect.contains(saveRect.bottomRight), isTrue);
            expect(find.text('Drafts stay on this device'), findsNothing);
            for (final note in [
              'Fields marked * are required. Select an option from each list.',
              'Optional. Add a clear photo to help your team identify this plant.',
              'Where this plant is physically planted.',
              'Select a CSU campus or Outside campus.',
            ]) {
              expect(find.text(note), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('web registration is centered and sections flow vertically', (
    tester,
  ) async {
    await fixture.open(tester, fixture.MemoryDrafts(), width: 1600);
    final form = tester.getRect(find.byKey(const Key('registration-web-form')));
    final plant = tester.getRect(
      find.byKey(const Key('registration-plant-section')),
    );
    final location = tester.getRect(
      find.byKey(const Key('registration-location-section')),
    );
    final photo = tester.getRect(find.text('Plant Photo'));
    expect(form.width, lessThanOrEqualTo(1120));
    expect(plant.left, closeTo(location.left, 1));
    expect(plant.bottom, lessThan(location.top));
    expect(location.bottom, lessThan(photo.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('render desktop and mobile registration previews', (
    tester,
  ) async {
    await (FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final width in [390.0, 1600.0]) {
      await fixture.open(tester, fixture.MemoryDrafts(), width: width);
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('registration-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/layout_previews').createSync(recursive: true);
        File(
          'build/layout_previews/registration-${width.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
