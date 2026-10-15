import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../../services/inspection_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/qr_problem_dialog.dart';
import '../admin/plant_service.dart';
import '../inspections/inspection_form_screen.dart';
import '../qr/qr_problem_reports_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final int plantId;
  final int userId;
  final String username;
  final String role;

  const PlantDetailScreen({
    super.key,
    required this.plantId,
    required this.userId,
    required this.username,
    required this.role,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final _service = InspectionService();
  final _plantService = PlantService();
  Map<String, dynamic>? _plant;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _savingAction = false;
  String? _error;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  String _value(dynamic value, [String fallback = 'Not provided']) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plant = await _service.getPlant(widget.plantId);
      List<Map<String, dynamic>> history = [];
      try {
        history = await _service.getInspections(widget.plantId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Plant Details'),
      backgroundColor: AppColors.background,
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? AppErrorState(
            title: 'Unable to load this plant',
            message: userFacingError(
              _error!,
              fallback:
                  'The plant details could not be loaded. Please try again.',
            ),
            technicalDetails: _error,
            onRetry: _load,
          )
        : _body(),
  );

  Widget _body() {
    final plant = _plant!;
    final classification = _map(plant['plant_classification']);
    final url = _value(plant['photo_url'], '');
    final canInspect = RoleCapabilities.fromValue(widget.role).canInspectPlants;
    final canArchive = RoleCapabilities.fromValue(widget.role).canArchivePlants;
    final archived = plant['archived_at'] != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          if (archived) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.archive_outlined, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This plant is archived${plant['archive_reason'] == null ? '' : ': ${plant['archive_reason']}'}. Restore it from Plant Records to make it active again.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 260,
              color: AppColors.primaryContainer,
              child: url.isEmpty
                  ? const Icon(
                      Icons.local_florist,
                      size: 90,
                      color: AppColors.green,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 70),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _value(classification['common_name'], 'Unnamed plant'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          Text(
            _value(classification['scientific_name']),
            style: const TextStyle(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _section('Plant Information', {
            'Plant ID': '#${plant['plant_id']}',
            'Date planted': _value(plant['date_planted']),
            'Tree planter': _value(plant['tree_planter']),
          }),
          _section('Classification', {
            'Plant type': _value(classification['plant_type']),
            'Common name': _value(classification['common_name']),
            'Variety': _value(plant['variety']),
          }),
          _section('Status', {
            'Health status': _value(
              _map(plant['health_status'])['status_name'],
            ),
            'Growth stage': _value(
              _map(plant['growth_status'])['growth_stage'],
            ),
          }),
          _inspectionScheduleSection(plant),
          _section('Location', {
            'Campus': _value(_map(plant['campus'])['campus_name']),
            'Department': _value(_map(plant['college'])['college_name']),
            'Barangay': _value(_map(plant['barangay'])['barangay_name']),
            'Town': _value(_map(plant['town'])['town_name']),
          }),
          if (_history.isNotEmpty) _historySection(),
          if ((canInspect || canArchive) && !archived)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => showQrProblemDialog(context, widget.plantId),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report QR problem'),
              ),
            ),
          if (canInspect || canArchive)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QrProblemReportsScreen(canReview: canArchive),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
              label: Text(canArchive ? 'Review QR reports' : 'My QR reports'),
            ),
          if (canInspect && !archived)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InspectionFormScreen(
                        plant: plant,
                        userId: widget.userId,
                      ),
                    ),
                  );
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Inspect Plant'),
              ),
            ),
          if (canArchive && !archived)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                onPressed: _savingAction ? null : _archivePlant,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _savingAction
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined),
                label: Text(_savingAction ? 'Archiving…' : 'Archive Plant'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _archivePlant() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Archive this plant?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The plant will leave active lists, but its profile, QR history, and inspections will be preserved.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Example: Duplicate record or plant removed',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _savingAction = true);
    try {
      await _plantService.archivePlant(plantId: widget.plantId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plant archived.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'The plant could not be archived. Try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
  }

  Future<void> _editInspectionSchedule(Map<String, dynamic> plant) async {
    final intervalController = TextEditingController(
      text: (plant['inspection_interval_days'] ?? 90).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var dueDate =
        _parseDate(plant['next_inspection_due_on']) ??
        today.add(const Duration(days: 90));
    if (dueDate.isBefore(today)) dueDate = today;
    final values = await showDialog<(DateTime, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Inspection schedule'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set the next visit and how often this plant should be inspected.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 3650)),
                      );
                      if (selected != null) {
                        setDialogState(() => dueDate = selected);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Next visit: ${_formatDate(dueDate)}'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: intervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeat every (days)',
                      prefixIcon: Icon(Icons.repeat_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 1 || parsed > 3650) {
                        return 'Enter a number from 1 to 3650.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, (
                  dueDate,
                  int.parse(intervalController.text.trim()),
                ));
              },
              child: const Text('Save schedule'),
            ),
          ],
        ),
      ),
    );
    intervalController.dispose();
    if (values == null || !mounted) return;
    setState(() => _savingAction = true);
    try {
      await _service.updateInspectionSchedule(
        plantId: widget.plantId,
        nextDueOn: values.$1,
        intervalDays: values.$2,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection schedule updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'The schedule could not be updated. Try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
  }

  Widget _section(String title, Map<String, String> rows) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...rows.entries.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _inspectionScheduleSection(Map<String, dynamic> plant) {
    final last = _parseDate(plant['last_inspected_on']);
    final next = _parseDate(plant['next_inspection_due_on']);
    final interval = plant['inspection_interval_days'];
    final status = _inspectionScheduleStatus(next);
    final (label, icon, foreground, background) = switch (status) {
      'overdue' => (
        'Overdue',
        Icons.warning_amber_rounded,
        AppColors.danger,
        AppColors.dangerContainer,
      ),
      'due_today' => (
        'Due today',
        Icons.today_rounded,
        AppColors.warning,
        AppColors.warningContainer,
      ),
      'upcoming' => (
        'Upcoming',
        Icons.upcoming_rounded,
        AppColors.info,
        AppColors.infoContainer,
      ),
      _ => (
        'Not scheduled',
        Icons.event_busy_outlined,
        AppColors.textSecondary,
        AppColors.surfaceDisabled,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inspection Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (RoleCapabilities.fromValue(widget.role).canArchivePlants &&
                  plant['archived_at'] == null)
                IconButton(
                  tooltip: 'Edit inspection schedule',
                  onPressed: _savingAction
                      ? null
                      : () => _editInspectionSchedule(plant),
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.green,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: foreground),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _scheduleRow(
            'Last inspected',
            last == null ? 'Not inspected' : _formatDate(last),
          ),
          _scheduleRow(
            'Next inspection',
            next == null ? 'Not scheduled' : _formatDate(next),
          ),
          if (interval != null)
            _scheduleRow(
              'Schedule repeats',
              'Every $interval day${interval.toString() == '1' ? '' : 's'}',
            ),
        ],
      ),
    );
  }

  Widget _scheduleRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  String _inspectionScheduleStatus(DateTime? next) {
    if (next == null) return 'unscheduled';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(next.year, next.month, next.day);
    if (due.isBefore(today)) return 'overdue';
    if (due == today) return 'due_today';
    return 'upcoming';
  }

  DateTime? _parseDate(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _historySection() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inspection History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ..._history
            .take(5)
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.green,
                ),
                title: Text(
                  '${_value(_map(item['growth_status'])['growth_stage'])} • ${_value(_map(item['health_status'])['status_name'])}',
                ),
                subtitle: Text(
                  [
                    _value(
                      item['inspected_at'] ?? item['last_inspection_date'],
                    ),
                    if (_value(item['observation'], '').isNotEmpty)
                      _value(item['observation']),
                  ].join('\n'),
                ),
              ),
            ),
      ],
    ),
  );
}
