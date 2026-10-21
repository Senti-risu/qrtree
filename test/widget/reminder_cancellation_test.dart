import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/inspection_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'logout cancels notifications and prevents queued refresh or test from rearming',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final reminders = InspectionReminders.instance;
      addTearDown(() => WidgetsBinding.instance.removeObserver(reminders));
      await reminders.cancel();
      await reminders.refresh();
      await expectLater(reminders.test(5), throwsStateError);
      expect(calls.where((method) => method == 'cancelAll').length, 1);
      expect(calls, isNot(contains('zonedSchedule')));
      expect(calls, isNot(contains('show')));
    },
  );
}
