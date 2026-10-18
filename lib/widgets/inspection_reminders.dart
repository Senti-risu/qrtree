import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/inspection_service.dart';

/// Daily in-app digest. No background notification or email permission needed.
class InspectionReminders extends StatefulWidget {
  const InspectionReminders({
    super.key,
    required this.scopeKey,
    required this.onOpen,
  });
  final String scopeKey;
  final VoidCallback onOpen;
  @override
  State<InspectionReminders> createState() => _InspectionRemindersState();
}

class _InspectionRemindersState extends State<InspectionReminders>
    with WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage();
  Timer? _timer;
  bool _loading = false;
  bool _dismissed = false;
  int _due = 0, _overdue = 0, _escalated = 0;
  String? _error;
  String get _today => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  String get _key => 'inspection_digest_${widget.scopeKey}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final rows = await InspectionService().listInspectionQueue().timeout(
        const Duration(seconds: 15),
      );
      final dismissed = await _storage.read(key: _key) == _today;
      if (!mounted) return;
      setState(() {
        _dismissed = dismissed;
        _error = null;
        _due = rows.where((p) => p['schedule_status'] == 'due_today').length;
        _overdue = rows.where((p) => p['schedule_status'] == 'overdue').length;
        _escalated = rows
            .where(
              (p) =>
                  ((p['days_overdue'] as num?) ?? 0) >=
                  2 * (((p['inspection_interval_days'] as num?) ?? 7)),
            )
            .length;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Inspection reminders unavailable. Tap to retry.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return TextButton(onPressed: _refresh, child: Text(_error!));
    }
    if (_dismissed || _due + _overdue == 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily inspection reminder • $_today',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('$_due due today • $_overdue overdue'),
            if (_escalated > 0)
              Text(
                '$_escalated need College Admin attention: overdue by at least two inspection intervals.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: widget.onOpen,
                  child: const Text('Review inspection queue'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await _storage.write(key: _key, value: _today);
                    } catch (_) {
                      return;
                    }
                    if (mounted) setState(() => _dismissed = true);
                  },
                  child: const Text('Dismiss for today'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
