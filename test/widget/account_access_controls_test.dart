import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/account_access_controls.dart';

void main() {
  for (final role in [
    'University Admin',
    'Campus Admin',
    'College Admin',
    'Inspection Team',
  ]) {
    for (final width in [320.0, 1100.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$role shared account layout at $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var statusChanges = 0;
          var edits = 0;
          var archives = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AccountAccessTile(
                      username: 'CSU_admin_account',
                      subtitle:
                          '$role · College of Information Technology · CSU Lasam',
                      statusButton: AccountStatusButton(
                        active: true,
                        onPressed: () => statusChanges++,
                      ),
                      actions: AccountRowActions(
                        onEdit: () => edits++,
                        onArchive: () => archives++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.textContaining(role), findsOneWidget);
          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(find.byType(Switch), findsNothing);
          for (final label in ['Active', 'Edit', 'Archive']) {
            expect(find.text(label).hitTestable(), findsOneWidget);
            await tester.tap(find.text(label));
          }
          expect(statusChanges, 1);
          expect(edits, 1);
          expect(archives, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final active in [true, false]) {
    testWidgets(
      '${active ? 'Active' : 'Inactive'} status is a pressable button',
      (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: AccountStatusButton(
                active: active,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );
        expect(find.text(active ? 'Active' : 'Inactive'), findsOneWidget);
        expect(
          find.byTooltip(active ? 'Deactivate Account' : 'Activate Account'),
          findsOneWidget,
        );
        await tester.tap(find.text(active ? 'Active' : 'Inactive'));
        expect(pressed, isTrue);
        expect(find.byType(Switch), findsNothing);
      },
    );
  }

  for (final width in [320.0, 390.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('status, edit and archive are visible at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edited = false;
        var archived = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AccountStatusButton(active: true, onPressed: () {}),
                      AccountRowActions(
                        onEdit: () => edited = true,
                        onArchive: () => archived = true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Active').hitTestable(), findsOneWidget);
        expect(find.text('Edit').hitTestable(), findsOneWidget);
        expect(find.text('Archive').hitTestable(), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        await tester.tap(find.text('Edit'));
        await tester.tap(find.text('Archive'));
        expect(edited, isTrue);
        expect(archived, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('busy account disables all actions without losing its status', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              AccountStatusButton(
                active: false,
                busy: true,
                onPressed: () => presses++,
              ),
              AccountRowActions(
                busy: true,
                onEdit: () => presses++,
                onArchive: () => presses++,
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in ['Inactive', 'Edit', 'Archive']) {
      await tester.tap(find.text(label));
    }
    expect(presses, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
