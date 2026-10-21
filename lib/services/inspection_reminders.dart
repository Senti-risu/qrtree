import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/app_role.dart';
import '../models/plant_record_lock.dart';
import 'app_session.dart';
import 'inspection_service.dart';
import 'persistent_session.dart';

/// Pure planner: one summary per day, limited to the next 30 days.
List<({DateTime at, int count})> planInspectionReminders(
  List<Map<String, dynamic>> plants,
  DateTime now,
  int hour,
  int minute,
) {
  final result = <({DateTime at, int count})>[];
  for (var offset = 0; offset < 30; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset, hour, minute);
    if (!day.isAfter(now)) continue;
    final ids = <Object>{};
    for (final plant in plants) {
      if (plant['archived_at'] != null || PlantRecordLock.isDead(plant)) {
        continue;
      }
      final due = DateTime.tryParse(
        '${plant['next_inspection_due_on'] ?? plant['next_inspection_due_date'] ?? ''}',
      );
      final last = DateTime.tryParse(
        '${plant['last_inspected_on'] ?? plant['last_inspection_date'] ?? ''}',
      );
      if (due == null || DateTime(due.year, due.month, due.day).isAfter(day)) {
        continue;
      }
      if (last != null && !last.isBefore(due)) continue;
      final id = plant['plant_id'];
      if (id != null) ids.add(id);
    }
    if (ids.isNotEmpty) result.add((at: day, count: ids.length));
  }
  return result;
}

class InspectionReminders with WidgetsBindingObserver {
  InspectionReminders._();
  static final instance = InspectionReminders._();
  final navigatorKey = GlobalKey<NavigatorState>();
  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  Future<void> _pending = Future.value();
  bool _initialized = false;
  bool _opening = false;
  bool _suspended = false;
  void resume() {
    _suspended = false;
    refreshQuietly();
  }

  String? launchPayload;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'inspection_reminders',
      'Inspection Reminders',
      channelDescription: 'Daily summaries of inspections due in EcoTag',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_inspection_notification',
    ),
  );

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_inspection_notification'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          unawaited(openQueue(response.payload)),
    );
    launchPayload = (await _plugin.getNotificationAppLaunchDetails())
        ?.notificationResponse
        ?.payload;
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  Future<Map<String, dynamic>> preferences(int userId) async {
    final raw = await _storage.read(key: 'inspection_reminders_$userId');
    if (raw == null) return {'enabled': false, 'hour': 8, 'minute': 0};
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return {
      'enabled': data['enabled'] == true,
      'hour': (data['hour'] as num? ?? 8).toInt().clamp(0, 23),
      'minute': (data['minute'] as num? ?? 0).toInt().clamp(0, 59),
    };
  }

  Future<void> configure(int userId, bool enabled, TimeOfDay time) async {
    await initialize();
    final key = 'inspection_reminders_$userId';
    final previous = await _storage.read(key: key);
    if (enabled &&
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() !=
            true) {
      throw StateError(
        'Notifications are disabled. Allow EcoTag notifications in Android settings.',
      );
    }
    await _storage.write(
      key: key,
      value: jsonEncode({
        'enabled': enabled,
        'hour': time.hour,
        'minute': time.minute,
      }),
    );
    try {
      if (enabled) {
        await refresh();
      } else {
        // Turning off must also work without a network/session refresh.
        await _serial(() => _plugin.cancelAll());
      }
    } catch (_) {
      if (previous == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: previous);
      }
      rethrow;
    }
  }

  /// Serial operations ensure logout cancellation runs after in-flight refreshes.
  Future<void> _serial(Future<void> Function() work) {
    final next = _pending.then((_) => work());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> cancel() {
    _suspended = true;
    return _serial(() async {
      if (!supported) return;
      await initialize();
      await _plugin.cancelAll();
    });
  }

  void refreshQuietly() => unawaited(
    refresh().catchError((Object error) {
      debugPrint(
        'Inspection reminders could not refresh: ${error.runtimeType}',
      );
    }),
  );

  Future<void> refresh() => _serial(() async {
    if (!supported || _suspended) return;
    await initialize();
    final user = await AppSession.validate().catchError((Object error) async {
      if (error is SessionRejected) await _plugin.cancelAll();
      throw error;
    });
    if (user == null ||
        !{
          AppRole.collegeAdmin,
          AppRole.inspectionTeam,
          AppRole.campusAdmin,
          AppRole.universityAdmin,
        }.contains(user.role)) {
      await _plugin.cancelAll();
      return;
    }
    final prefs = await preferences(user.userId);
    if (prefs['enabled'] != true) {
      await _plugin.cancelAll();
      return;
    }
    final token = AppSession.requiredToken;
    final plants = await InspectionService()
        .listInspectionQueue(filter: 'all')
        .timeout(const Duration(seconds: 15));
    if (_suspended ||
        !AppSession.isAuthenticated ||
        AppSession.requiredToken != token) {
      return;
    }
    final location = tz.getLocation('Asia/Manila');
    final now = tz.TZDateTime.now(location);
    final plan = planInspectionReminders(
      plants,
      DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second),
      prefs['hour'] as int,
      prefs['minute'] as int,
    );
    await _plugin.cancelAll();
    for (var i = 0; i < plan.length; i++) {
      final item = plan[i];
      await _plugin.zonedSchedule(
        id: 41000 + i,
        title: 'Inspection reminders',
        body:
            '${item.count} plants need inspection. Open your queue to review.',
        scheduledDate: tz.TZDateTime(
          location,
          item.at.year,
          item.at.month,
          item.at.day,
          item.at.hour,
          item.at.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${user.userId}',
      );
    }
  });

  Future<void> test(int userId) => _serial(() async {
    if (_suspended) throw StateError('Sign in again before testing reminders.');
    await initialize();
    final user = await AppSession.validate();
    if (user?.userId != userId) {
      throw StateError('Your account changed. Open reminder settings again.');
    }
    if (await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() !=
        true) {
      throw StateError('Allow EcoTag notifications in Android settings first.');
    }
    if (_suspended) return;
    await _plugin.show(
      id: 40999,
      title: 'EcoTag test notification',
      body: 'Inspection reminders are ready on this phone.',
      notificationDetails: _details,
      payload: '$userId',
    );
  });

  Future<void> openQueue(String? payload) async {
    if (_opening) return;
    _opening = true;
    try {
      final user = await AppSession.validate();
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      if (user == null) {
        nav.pushNamedAndRemoveUntil('/staff-login', (_) => false);
        return;
      }
      if (payload != '${user.userId}') return;
      // Preserve an unfinished registration/inspection beneath the queue.
      await nav.pushNamed('/inspections', arguments: user.arguments);
    } catch (_) {
      // Keep the session bootstrap retry UI when validation is unavailable.
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    } finally {
      _opening = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshQuietly();
  }
}
