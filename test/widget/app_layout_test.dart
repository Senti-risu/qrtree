import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/theme/app_layout.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_shell.dart';

void main() {
  group('EcoTag responsive layout tokens', () {
    test('classifies every breakpoint boundary deliberately', () {
      expect(AppBreakpoints.isPhone(0), isTrue);
      expect(AppBreakpoints.isPhone(599.99), isTrue);
      expect(AppBreakpoints.isPhone(600), isFalse);

      expect(AppBreakpoints.isTablet(599.99), isFalse);
      expect(AppBreakpoints.isTablet(600), isTrue);
      expect(AppBreakpoints.isTablet(899.99), isTrue);
      expect(AppBreakpoints.isTablet(900), isFalse);

      expect(AppBreakpoints.isDesktop(899.99), isFalse);
      expect(AppBreakpoints.isDesktop(900), isTrue);
    });

    test('keeps the approved spacing and sizing scale', () {
      expect(
        const <double>[
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ],
        const <double>[4, 8, 12, 16, 24],
      );
      expect(AppLayout.maxContentWidth, 1520);
      expect(AppLayout.minimumTapTarget, 48);
      expect(AppLayout.pagePadding(599).left, AppSpacing.lg);
      expect(AppLayout.pagePadding(600).left, AppSpacing.xl);
    });
  });

  group('AppShell scroll ownership', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required Size size,
      required Key contentKey,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(
            activeRoute: '/dashboard',
            mobileTitle: 'Dashboard',
            userId: 1,
            username: 'admin',
            role: 'college_admin',
            campusId: 1,
            collegeId: 1,
            showQrButton: false,
            child: SizedBox.expand(key: contentKey),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('leaves scrolling to the page on phone layouts', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const contentKey = Key('mobile-page-content');

      await pumpShell(
        tester,
        size: const Size(390, 844),
        contentKey: contentKey,
      );

      expect(
        find.ancestor(
          of: find.byKey(contentKey),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaves scrolling to the page on desktop layouts', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const contentKey = Key('desktop-page-content');

      await pumpShell(
        tester,
        size: const Size(1280, 800),
        contentKey: contentKey,
      );

      expect(
        find.ancestor(
          of: find.byKey(contentKey),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
