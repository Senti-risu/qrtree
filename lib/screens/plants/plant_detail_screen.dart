import 'package:flutter/material.dart';
import '../../models/inspection_schedule.dart';

import '../../models/app_role.dart';
import '../../models/plant_record_lock.dart';
import '../../widgets/dead_plant_lock.dart';
import '../../services/inspection_service.dart';
import '../../services/plant_location_service.dart';
import '../../widgets/plant_details_editor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/health_status_label.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/qr_problem_dialog.dart';
import '../../widgets/plant_details_presentation.dart';
import '../../widgets/plant_detail_content.dart';
import '../../widgets/plant_ecotag_header.dart';
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
  Map<String, dynamic> _physicalLocation = {};
  String? _locationError;

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
      try {
        _physicalLocation = await PlantLocationService().get(widget.plantId);
        _locationError = null;
      } catch (e) {
        _physicalLocation = {};
        _locationError = userFacingError(e);
      }
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
      leading: PlantDetailsPresentation.floatsFor(MediaQuery.sizeOf(context))
          ? IconButton(
              tooltip: 'Close plant details',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
            )
          : const BackButton(),
      backgroundColor: AppColors.background,
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
        : SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _body(),
              ),
            ),
          ),
  );

  Widget _body() {
    final plant = _plant!;
    final classification = _map(plant['plant_classification']);
    final url = _value(plant['photo_url'], '');
    final canInspect = RoleCapabilities.fromValue(widget.role).canInspectPlants;
    final canArchive = RoleCapabilities.fromValue(widget.role).canArchivePlants;
    final archived = plant['archived_at'] != null;
    final dead = PlantRecordLock.isDead(plant);
    final editable = PlantRecordLock.canEdit(plant);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          PlantEcoTagHeader(
            code: _map(plant['qr_tag'])['qr_code_string']?.toString(),
          ),
          if (dead)
            DeadPlantLockNotice(
              onReopen: canArchive && !archived && !_savingAction
                  ? _reopenDeadPlant
                  : null,
            ),
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
          PlantDetailHero(
            name: _value(classification['common_name'], 'Unnamed plant'),
            scientificName: _value(classification['scientific_name']),
            plantId: '${plant['plant_id']}',
            imageUrl: url,
          ),
          _section('Managed by', {
            'Managing campus': _value(_map(plant['campus'])['campus_name']),
            'Managing college': _value(_map(plant['college'])['college_name']),
          }),
          _section('Plant Classification', {
            'Plant type': _value(classification['plant_type']),
            'Common name': _value(classification['common_name']),
            'Scientific name': _value(classification['scientific_name']),
            'Variety': _value(plant['variety']),
            'Growth stage': _value(
              _map(plant['growth_status'])['growth_stage'],
            ),
            'Health status': healthStatusLabel(
              _map(plant['health_status'])['status_name'],
            ),
            'Date planted': _parseDate(plant['date_planted']) == null
                ? _value(plant['date_planted'])
                : _formatDate(_parseDate(plant['date_planted'])!),
            'Tree planter': _value(plant['tree_planter']),
          }),
          _section('Planting location', {
            'Campus / outside':
                _locationError ?? PlantLocationService.label(_physicalLocation),
            'Town': _value(_map(plant['town'])['town_name']),
            'Barangay': _value(_map(plant['barangay'])['barangay_name']),
          }),
          _inspectionScheduleSection(plant),
          if (canInspect || canArchive) ...[
            PlantDetailActions(
              singleColumn: true,
              children: [
                if (canInspect && editable)
                  Padding(
                    padding: EdgeInsets.zero,
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
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Inspect Plant'),
                    ),
                  ),
                if ((canInspect || canArchive) && editable)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final changed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PlantDetailsEditor(
                          plantId: widget.plantId,
                          userId: widget.userId,
                        ),
                      );
                      if (changed == true && mounted) _load();
                    },
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Update plant details'),
                  ),
                if ((canInspect || canArchive) && !archived)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showQrProblemDialog(context, widget.plantId),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Report QR problem'),
                    ),
                  ),
                if (canInspect || canArchive)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            QrProblemReportsScreen(canReview: canArchive),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: Text(
                      canArchive ? 'Review QR reports' : 'My QR reports',
                    ),
                  ),
                if (canArchive && !archived)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: OutlinedButton.icon(
                      onPressed: _savingAction ? null : _archivePlant,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _savingAction
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: Text(
                        _savingAction ? 'Archiving…' : 'Archive Plant',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (_history.isNotEmpty) _historySection(),
        ],
      ),
    );
  }

  Future<void> _reopenDeadPlant() async {
    setState(() => _savingAction = true);
    try {
      final statuses = (await _plantService.getHealthStatuses())
          .where((s) => !PlantRecordLock.isDeadStatus(s['status_name']))
          .toList();
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReopenDeadPlantDialog(
          statuses: statuses,
          onSave: (healthId, reason) => _plantService.reopenDeadPlant(
            plantId: widget.plantId,
            healthStatusId: healthId,
            reason: reason,
          ),
        ),
      );
      if (changed == true && mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
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
      text: InspectionSchedule.intervalDays(plant).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var dueDate =
        _parseDate(plant['next_inspection_due_on']) ??
        today.add(Duration(days: InspectionSchedule.intervalDays(plant)));
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

  Widget _section(String title, Map<String, String> rows) =>
      PlantDetailFields(title: title, rows: rows);

  Widget _inspectionScheduleSection(Map<String, dynamic> plant) {
    if (PlantRecordLock.isDead(plant)) {
      return _section('Inspection Schedule', {
        'Schedule': 'Stopped — plant confirmed Dead',
        'Last inspection': _value(plant['last_inspected_on']),
      });
    }
    final last = _parseDate(plant['last_inspected_on']);
    final next = _parseDate(plant['next_inspection_due_on']);
    final interval = InspectionSchedule.intervalDays(plant);
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

    return PlantDetailFields(
      title: 'Inspection Schedule',
      trailing:
          RoleCapabilities.fromValue(widget.role).canArchivePlants &&
              plant['archived_at'] == null
          ? IconButton(
              tooltip: 'Edit inspection schedule',
              onPressed: _savingAction
                  ? null
                  : () => _editInspectionSchedule(plant),
              icon: const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.green,
              ),
            )
          : null,
      badge: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(icon, size: 15, color: foreground),
                ),
                TextSpan(text: ' $label'),
              ],
            ),
            style: TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
      rows: {
        'Last inspected': last == null ? 'Not inspected' : _formatDate(last),
        'Next inspection': next == null ? 'Not scheduled' : _formatDate(next),
        'Schedule repeats': 'Every $interval day${interval == 1 ? '' : 's'}',
      },
    );
  }

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
