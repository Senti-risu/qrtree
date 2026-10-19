import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/plant_record_lock.dart';
import 'package:flutter_application_1/widgets/dead_plant_lock.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/utils/user_facing_error.dart';

void main() {
  test('dead status locks nested plant and flat queue records', () {
    for (final status in ['Dead', ' dead ', 'DECEASED']) {
      expect(
        PlantRecordLock.canEdit({
          'health_status': {'status_name': status},
        }),
        isFalse,
      );
      expect(PlantRecordLock.isDead({'health_status': status}), isTrue);
    }
    expect(
      PlantRecordLock.canEdit({
        'health_status': {'status_name': 'Healthy'},
      }),
      isTrue,
    );
    expect(
      PlantRecordLock.canEdit({
        'health_status': 'Healthy',
        'archived_at': '2026-10-16',
      }),
      isFalse,
    );
  });

  test('lock errors provide a useful action', () {
    expect(
      userFacingError(StateError('Dead plant is locked')),
      contains('College Admin'),
    );
  });

  testWidgets('dead confirmation can be cancelled or explicitly accepted', (
    tester,
  ) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  confirmed = await confirmDeadPlant(context),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Dead'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets(
    'lock notice fits narrow screens and shows no unauthorized reopen action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: DeadPlantLockNotice()),
          ),
        ),
      );
      expect(find.text('Dead Plant — Record Locked'), findsOneWidget);
      expect(find.text('Reopen / correct record'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening requires status and reason and excludes Dead', (
    tester,
  ) async {
    int? savedHealth;
    String? savedReason;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ReopenDeadPlantDialog(
                  statuses: const [
                    {'health_status_id': 1, 'status_name': 'Healthy'},
                    {'health_status_id': 2, 'status_name': 'Dead'},
                  ],
                  onSave: (healthId, reason) async {
                    savedHealth = healthId;
                    savedReason = reason;
                  },
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
    await tester.tap(find.text('Reopen record'));
    await tester.pumpAndSettle();
    expect(find.text('Select the correct status.'), findsOneWidget);
    expect(find.text('Enter at least 3 characters.'), findsOneWidget);
    expect(savedHealth, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('Dead'), findsNothing);
    await tester.tap(find.text('Healthy').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      ' Incorrect observation corrected ',
    );
    await tester.tap(find.text('Reopen record'));
    await tester.pumpAndSettle();
    expect(savedHealth, 1);
    expect(savedReason, 'Incorrect observation corrected');
    expect(find.byType(ReopenDeadPlantDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
