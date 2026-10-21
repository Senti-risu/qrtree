import 'package:flutter/material.dart';
import '../../services/inspection_reminders.dart';
import '../../services/app_session.dart';
import '../../utils/user_facing_error.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _reminders = InspectionReminders.instance;
  int? _userId;
  bool _enabled = false, _busy = true;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AppSession.restore();
      if (user == null) {
        throw StateError('Sign in again to configure reminders.');
      }
      final prefs = await _reminders.preferences(user.userId);
      if (!mounted) return;
      setState(() {
        _userId = user.userId;
        _enabled = prefs['enabled'] == true;
        _time = TimeOfDay(
          hour: prefs['hour'] as int,
          minute: prefs['minute'] as int,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inspection Reminders')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Daily summaries use Philippine time and the last schedules downloaded to this phone. Open EcoTag regularly to refresh them. Reminders are prepared for the next 30 days.',
        ),
        if (!_reminders.supported)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Local reminders are available in the Android app.'),
          ),
        SwitchListTile(
          title: const Text('Enable Reminders'),
          value: _enabled,
          onChanged: _busy || _userId == null || !_reminders.supported
              ? null
              : (value) => _run(() async {
                  await _reminders.configure(_userId!, value, _time);
                  if (mounted) setState(() => _enabled = value);
                }),
        ),
        ListTile(
          title: const Text('Reminder Time'),
          subtitle: Text('${_time.format(context)} · Philippine time'),
          trailing: const Icon(Icons.schedule),
          onTap: _busy || _userId == null || !_reminders.supported
              ? null
              : () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (time == null || !mounted) return;
                  await _run(() async {
                    await _reminders.configure(_userId!, _enabled, time);
                    if (mounted) setState(() => _time = time);
                  });
                },
        ),
        OutlinedButton.icon(
          onPressed: _busy || _userId == null || !_reminders.supported
              ? null
              : () => _run(() => _reminders.test(_userId!)),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Test Notification'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
