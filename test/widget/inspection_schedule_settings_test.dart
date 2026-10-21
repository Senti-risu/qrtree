import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/inspection_schedule_settings_screen.dart';
import 'package:flutter_application_1/services/inspection_schedule_settings_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';

class MemoryInspectionScheduleSettings implements InspectionScheduleSettings {
  int days = 7;
  int? savedDays;

  @override
  Future<int> getIntervalDays() async => days;

  @override
  Future<int> setIntervalDays(int value) async {
    savedDays = value;
    days = value;
    return value;
  }
}

void main() {
  testWidgets('university admin can set a global 30-day interval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = MemoryInspectionScheduleSettings();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: InspectionScheduleSettingsScreen(
          userId: 1,
          username: 'University Admin',
          role: 'university_admin',
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(find.text('Inspection Schedule'), findsWidgets);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('current-inspection-interval')),
          )
          .data,
      '7',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Update university inspection schedule?'), findsOneWidget);
    expect(
      find.textContaining(
        'resets every active plant’s next inspection date',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Update Schedule'));
    await tester.pumpAndSettle();

    expect(settings.savedDays, 30);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('current-inspection-interval')),
          )
          .data,
      '30',
    );
    expect(
      find.text('Inspection schedule updated for all campuses and admins.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule controls adapt to a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: InspectionScheduleSettingsScreen(
          userId: 1,
          username: 'University Admin',
          role: 'university_admin',
          settings: MemoryInspectionScheduleSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('current-inspection-interval')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '7 days'), findsOneWidget);
    expect(find.text('Save Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
