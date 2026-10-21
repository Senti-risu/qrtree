import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/reports/widgets/report_readable_widgets.dart';
import 'package:flutter_application_1/screens/admin/registration/widgets/plant_image_picker_field.dart';
import 'package:flutter_application_1/theme/app_colors.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/theme/app_typography.dart';
import 'package:flutter_application_1/widgets/app_card.dart';

const college = 'College of Information and Computing Sciences, CSU Lasam';
const values = [
  ('Healthy', 120, AppColors.green),
  ('Needs Attention', 32, AppColors.warningAccent),
  ('Dead', 4, AppColors.danger),
];

Widget sample(double width) => AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Plant Health',
        style: TextStyle(
          fontSize: AppTypography.sectionTitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      const ReportHealthDistribution(values: values),
      const SizedBox(height: 24),
      ReportDetailField(label: 'College', value: college, width: width),
      const SizedBox(height: 24),
      PlantImagePickerField(
        imageBytes: null,
        imageName: null,
        isPicking: false,
        onPick: () {},
        onRemove: () {},
      ),
    ],
  ),
);

void main() {
  for (final width in [280.0, 320.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('report legends, details and photo at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var picked = false;
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ReportHealthDistribution(values: values),
                      ReportDetailField(
                        label: 'College',
                        value: college,
                        width: width - 32,
                      ),
                      PlantImagePickerField(
                        imageBytes: null,
                        imageName: null,
                        isPicking: false,
                        onPick: () => picked = true,
                        onRemove: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final detail = tester.widget<Text>(find.text(college));
        expect(detail.maxLines, isNull);
        expect(detail.style!.fontSize, AppTypography.body);
        expect(
          tester.widget<Text>(find.text('College')).style!.fontSize,
          AppTypography.caption,
        );
        expect(
          tester.widget<Text>(find.text('Upload Image')).style!.fontSize,
          AppTypography.label,
        );
        expect(
          tester.widget<Text>(find.text('PNG, JPG Or JPEG')).style!.fontSize,
          AppTypography.caption,
        );
        await tester.ensureVisible(find.text('Choose Photo'));
        await tester.tap(find.text('Choose Photo'));
        expect(picked, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('render readable report and photo preview', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('readability-preview'),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: sample(310),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('readability-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/layout_previews').createSync(recursive: true);
      File(
        'build/layout_previews/readable-report.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
