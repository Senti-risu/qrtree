import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/admin/dashboard/widgets/dashboard_stat_card.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets(
    'compact totals fit two columns at 320px and zero counts are tappable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = '';
      Widget card(String title) => SizedBox(
        width: 136,
        child: DashboardStatCard(
          compact: true,
          title: title,
          value: '0',
          subtext: '0% of total plants',
          icon: Icons.eco,
          iconBgColor: Colors.greenAccent,
          iconColor: Colors.green,
          onTap: () => selected = title,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  card('Total Plants'),
                  card('Healthy Plants'),
                  card('At Risk'),
                  card('Dead Plants'),
                ],
              ),
            ),
          ),
        ),
      );
      final total = tester.getRect(find.byType(DashboardStatCard).at(0));
      final healthy = tester.getRect(find.byType(DashboardStatCard).at(1));
      expect(total.top, healthy.top);
      expect(total.height, lessThan(142));
      expect(
        tester.getRect(find.text('0').first).right,
        closeTo(total.right - 9, .01), // 8px padding + 1px card border.
      );
      await tester.tap(find.text('At Risk'));
      expect(selected, 'At Risk');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact statistic supports large text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 288,
              child: DashboardStatCard(
                compact: true,
                title: 'Healthy Plants',
                value: '12000',
                subtext: '100% of total plants',
                icon: Icons.eco,
                iconBgColor: Colors.greenAccent,
                iconColor: Colors.green,
                progress: 1,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('100% of total plants'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
