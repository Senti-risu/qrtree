import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/theme/app_typography.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/inspection_overview_card.dart';
import 'package:flutter_application_1/widgets/plant_detail_content.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/campus_overview_card.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/recent_plants_table.dart';
import 'package:flutter_application_1/screens/admin/reports/widgets/report_table_card.dart';

void main() {
  test('theme uses a shared hierarchy for inherited text and controls', () {
    final theme = AppTheme.light;
    for (final text in [theme.textTheme, theme.primaryTextTheme]) {
      expect(text.headlineSmall?.fontSize, AppTypography.pageTitle);
      expect(text.titleLarge?.fontSize, AppTypography.sectionTitle);
      expect(text.titleMedium?.fontSize, AppTypography.itemTitle);
      expect(text.bodyLarge?.fontSize, AppTypography.body);
      expect(text.bodyMedium?.fontSize, AppTypography.body);
      expect(text.bodySmall?.fontSize, AppTypography.caption);
      expect(text.labelLarge?.fontSize, AppTypography.label);
    }
    for (final style in [
      theme.filledButtonTheme.style,
      theme.elevatedButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      expect(style?.textStyle?.resolve({})?.fontSize, AppTypography.label);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('equivalent card headings match at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: const Size(1000, 1200),
                textScaler: TextScaler.linear(scale),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const AppPageHeader(
                      title: 'Dashboard',
                      subtitle: 'Plant monitoring',
                    ),
                    InspectionOverviewCard(
                      availableWidth: 1000,
                      metrics: const [],
                      lastInspection: 'No inspections yet',
                      message: 'Scan a tag',
                      actions: const [],
                    ),
                    RecentPlantsTable(plants: const [], onViewAll: () {}),
                    const CampusOverviewCard(counts: {}),
                    const ReportTableCard(
                      title: 'Detailed Plant Report',
                      columns: [],
                      rows: [],
                    ),
                    const PlantDetailFields(
                      title: 'Plant Information',
                      rows: {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (final title in [
        'Inspection Overview',
        'Recent Plants',
        'CSU Campuses',
        'Detailed Plant Report',
        'Plant Information',
      ]) {
        expect(
          tester.widget<Text>(find.text(title)).style?.fontSize,
          AppTypography.sectionTitle,
        );
      }
      final heading = tester.widget<Text>(find.text('Dashboard'));
      expect(heading.style?.fontSize, AppTypography.pageTitle);
      expect(tester.takeException(), isNull);
    });
  }
}
