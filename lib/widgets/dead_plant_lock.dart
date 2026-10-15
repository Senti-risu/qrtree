import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/user_facing_error.dart';
import '../models/plant_record_lock.dart';

Future<bool> confirmDeadPlant(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Confirm plant is dead?'),
        content: const Text(
          'Saving Dead will lock routine edits and stop future inspections. '
          'Its details, history, and QR reporting stay available. '
          'Only your College Admin can reopen the record with a recorded reason. '
          'A replacement plant must be registered separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Dead'),
          ),
        ],
      ),
    ) ??
    false;

class DeadPlantLockNotice extends StatelessWidget {
  const DeadPlantLockNotice({super.key, this.onReopen});
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: AppColors.warningContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_outline),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dead plant — record locked',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Routine edits and new inspections are disabled. Details, '
          'history, and QR reporting remain available. Register any replacement '
          'plant as a new record. A College Admin can correct an accidental '
          'Dead status with a recorded reason.',
        ),
        if (onReopen != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReopen,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Reopen / correct record'),
          ),
        ],
      ],
    ),
  );
}

class ReopenDeadPlantDialog extends StatefulWidget {
  const ReopenDeadPlantDialog({
    super.key,
    required this.statuses,
    required this.onSave,
  });
  final List<Map<String, dynamic>> statuses;
  final Future<void> Function(int healthId, String reason) onSave;
  @override
  State<ReopenDeadPlantDialog> createState() => _ReopenDeadPlantDialogState();
}

class _ReopenDeadPlantDialogState extends State<ReopenDeadPlantDialog> {
  final _form = GlobalKey<FormState>();
  int? _healthId;
  String _reason = '';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_healthId!, _reason.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(
            error,
            fallback: 'The record could not be reopened. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Reopen dead plant record'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Use this only to correct the existing plant record. '
                'Do not reuse it for a replacement plant. '
                'Your reason and status change will be saved in the Activity Log.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Correct health status',
                ),
                items: widget.statuses
                    .where(
                      (s) => !PlantRecordLock.isDeadStatus(s['status_name']),
                    )
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s['health_status_id'] as int,
                        child: Text(
                          '${s['status_name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving ? null : (value) => _healthId = value,
                validator: (value) =>
                    value == null ? 'Select the correct status.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters.'
                    : null,
                onSaved: (value) => _reason = value ?? '',
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Reopen record'),
        ),
      ],
    ),
  );
}
