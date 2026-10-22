import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_application_1/screens/qr/widgets/qr_numbering_info.dart';
import 'package:flutter_application_1/widgets/app_mobile_more_sheet.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'QR numbering explanation is optional and accessible / $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
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
            home: const Scaffold(body: Center(child: QrNumberingInfo())),
          ),
        );
        expect(find.text(QrNumberingInfo.explanation), findsNothing);
        await tester.tap(find.text('QR Code Format'));
        await tester.pumpAndSettle();
        expect(find.text(QrNumberingInfo.explanation), findsOneWidget);
        expect(QrNumberingInfo.explanation, contains('CSU-YYYYMM'));
        expect(QrNumberingInfo.explanation, isNot(contains('ECOTAG')));
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in [
    'super_admin',
    'university_admin',
    'campus_admin',
    'college_admin',
    'inspection_team',
  ]) {
    testWidgets('$role More menu keeps actions without repeated descriptions', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'EcoTag',
        packageName: 'test.ecotag',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppMobileMoreAction? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showAppMobileMoreSheet(
                  context,
                  displayName: 'Tester',
                  displayRole: role,
                  role: role,
                ),
                child: const Text('Open More'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open More'));
      await tester.pumpAndSettle();
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(tiles, isNotEmpty);
      expect(tiles.every((tile) => tile.subtitle == null), isTrue);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('How To Use EcoTag'), findsNothing);
      expect(find.text('Help'), findsNothing);
      expect(find.text('View your account and access details'), findsNothing);
      if (role == 'university_admin') {
        expect(find.text('Inspection Schedule'), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Sign Out'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(result, AppMobileMoreAction.logout);
      expect(tester.takeException(), isNull);
    });
  }
}
