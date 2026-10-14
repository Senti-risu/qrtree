import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/inspection_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_shell.dart';
import '../plants/plant_detail_screen.dart';
import 'inspection_form_screen.dart';

class InspectionHistoryScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const InspectionHistoryScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _queue = [];
  bool _loading = true;
  bool _queueLoading = true;
  String? _error;
  String? _queueError;
  String _healthFilter = 'all';
  String _growthFilter = 'all';
  String _queueFilter = 'action';
  int? _openingInspectionPlantId;
  int _loadRequestId = 0;
  int _queueRequestId = 0;

  static const Map<String, String> _queueFilters = {
    'action': 'Needs action',
    'due_today': 'Due today',
    'overdue': 'Overdue',
    'upcoming': 'Upcoming',
    'completed': 'Completed',
    'history': 'History',
  };

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleInspections {
    final term = _searchController.text.trim().toLowerCase();
    return _inspections.where((inspection) {
      final plant = _map(inspection['plant']);
      final classification = _map(plant['plant_classification']);
      final health =
          _map(inspection['health_status'])['status_name']?.toString().trim() ??
          'Unknown';
      final growth =
          _map(
            inspection['growth_status'],
          )['growth_stage']?.toString().trim() ??
          'Unknown';

      if (_healthFilter != 'all' && health != _healthFilter) return false;
      if (_growthFilter != 'all' && growth != _growthFilter) return false;
      if (term.isEmpty) return true;

      final searchable = [
        classification['common_name'],
        plant['variety'],
        plant['plant_id'],
        _map(inspection['users'])['username'],
        inspection['observation'],
      ].where((value) => value != null).join(' ').toLowerCase();
      return searchable.contains(term);
    }).toList();
  }

  List<String> _filterOptions(String relationKey, String valueKey) {
    final values = <String>{};
    for (final inspection in _inspections) {
      final value = _map(inspection[relationKey])[valueKey]?.toString().trim();
      if (value != null && value.isNotEmpty) values.add(value);
    }
    return values.toList()..sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
  }

  String _normalizedFilter(
    String current,
    List<Map<String, dynamic>> inspections,
    String relationKey,
    String valueKey,
  ) {
    if (current == 'all') return current;
    final exists = inspections.any(
      (inspection) =>
          _map(inspection[relationKey])[valueKey]?.toString().trim() == current,
    );
    return exists ? current : 'all';
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _healthFilter != 'all' ||
      _growthFilter != 'all';

  int get _activeFilterCount =>
      (_healthFilter == 'all' ? 0 : 1) + (_growthFilter == 'all' ? 0 : 1);

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _healthFilter = 'all';
      _growthFilter = 'all';
    });
  }

  Future<void> _openMobileFilters() async {
    var draftHealth = _healthFilter;
    var draftGrowth = _growthFilter;
    final healthOptions = _filterOptions('health_status', 'status_name');
    final growthOptions = _filterOptions('growth_status', 'growth_stage');
    final selected = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter inspections',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Narrow results by plant condition',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sheetFilterChoices(
                    label: 'HEALTH STATUS',
                    allLabel: 'All health',
                    value: draftHealth,
                    options: healthOptions,
                    onChanged: (value) =>
                        setSheetState(() => draftHealth = value),
                  ),
                  const SizedBox(height: 20),
                  _sheetFilterChoices(
                    label: 'GROWTH STAGE',
                    allLabel: 'All stages',
                    value: draftGrowth,
                    options: growthOptions,
                    onChanged: (value) =>
                        setSheetState(() => draftGrowth = value),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            draftHealth = 'all';
                            draftGrowth = 'all';
                          }),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, (
                            draftHealth,
                            draftGrowth,
                          )),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final (health, growth) = selected;
    if (health == _healthFilter && growth == _growthFilter) return;
    setState(() {
      _healthFilter = health;
      _growthFilter = growth;
    });
  }

  Widget _sheetFilterChoices({
    required String label,
    required String allLabel,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            [
              ('all', allLabel),
              ...options.map((option) => (option, option)),
            ].map((option) {
              final selected = value == option.$1;
              return ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.green,
                      )
                    : null,
                label: Text(option.$2),
                labelStyle: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.darkGreen : AppColors.textPrimary,
                ),
                selectedColor: AppColors.primaryContainer,
                backgroundColor: AppColors.background,
                side: BorderSide(
                  color: selected ? AppColors.green : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (_) => onChanged(option.$1),
              );
            }).toList(),
      ),
    ],
  );

  Future<void> _loadHistory() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _supabase.from('inspection').select('''
        *,
        plant (plant_id, college_id, campus_id, variety, plant_classification (common_name)),
        health_status (status_name), growth_status (growth_stage), users (username)
      ''');

      final rows = List<Map<String, dynamic>>.from(
        await query.order('inspected_at', ascending: false),
      );
      final visible = rows.where((inspection) {
        final plant = _map(inspection['plant']);
        if ((widget.role == 'inspection_team' ||
                widget.role == 'college_admin') &&
            widget.collegeId != null) {
          return plant['college_id'] == widget.collegeId;
        }
        if (widget.role == 'campus_admin' && widget.campusId != null) {
          return plant['campus_id'] == widget.campusId;
        }
        return true;
      }).toList();

      if (!mounted || requestId != _loadRequestId) return;
      final normalizedHealth = _normalizedFilter(
        _healthFilter,
        visible,
        'health_status',
        'status_name',
      );
      final normalizedGrowth = _normalizedFilter(
        _growthFilter,
        visible,
        'growth_status',
        'growth_stage',
      );
      setState(() {
        _inspections = visible;
        _healthFilter = normalizedHealth;
        _growthFilter = normalizedGrowth;
        _loading = false;
      });
    } catch (e) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadQueue() async {
    if (_queueFilter == 'history') return;
    final requestId = ++_queueRequestId;
    setState(() {
      _queueLoading = true;
      _queueError = null;
    });
    try {
      final rows = await _inspectionService.listInspectionQueue(
        filter: _queueFilter,
      );
      if (!mounted || requestId != _queueRequestId) return;
      setState(() {
        _queue = rows;
        _queueLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _queueRequestId) return;
      setState(() {
        _queue = const [];
        _queueLoading = false;
        _queueError = technicalErrorDetails(error);
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadHistory(),
      if (_queueFilter != 'history') _loadQueue(),
    ]);
  }

  void _selectQueueFilter(String filter) {
    if (filter == _queueFilter) return;
    setState(() => _queueFilter = filter);
    if (filter != 'history') _loadQueue();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    activeRoute: '/inspections',
    mobileTitle: 'Inspections',
    mobileSubtitle: _queueFilter == 'history'
        ? '${_visibleInspections.length} of ${_inspections.length} inspection records'
        : '${_queue.length} ${(_queueFilters[_queueFilter] ?? 'scheduled').toLowerCase()}',
    userId: widget.userId,
    username: widget.username,
    role: widget.role,
    campusId: widget.campusId,
    collegeId: widget.collegeId,
    userName: widget.username,
    onRefresh: _refreshAll,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AppBreakpoints.isDesktop(MediaQuery.sizeOf(context).width)) ...[
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspections',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Prioritize scheduled work and review completed inspections',
                  style: TextStyle(fontSize: 12, color: AppColors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        _queueSwitcher(),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _queueFilter == 'history' ? _content() : _queueContent(),
        ),
      ],
    ),
  );

  Widget _queueSwitcher() => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.event_note_rounded, color: AppColors.green, size: 21),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Inspection queue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Start with overdue and due-today plants, or review completed work.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _queueFilters.entries.map((entry) {
              final selected = _queueFilter == entry.key;
              final urgent = entry.key == 'action' || entry.key == 'overdue';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    _queueFilterIcon(entry.key),
                    size: 17,
                    color: selected
                        ? urgent
                              ? AppColors.danger
                              : AppColors.green
                        : AppColors.textSecondary,
                  ),
                  label: Text(entry.value),
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? urgent
                              ? AppColors.danger
                              : AppColors.darkGreen
                        : AppColors.textSecondary,
                  ),
                  selectedColor: urgent
                      ? AppColors.dangerContainer
                      : AppColors.primaryContainer,
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color: selected
                        ? urgent
                              ? AppColors.danger.withValues(alpha: .45)
                              : AppColors.green.withValues(alpha: .45)
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
                  onSelected: (_) => _selectQueueFilter(entry.key),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );

  IconData _queueFilterIcon(String filter) => switch (filter) {
    'action' => Icons.priority_high_rounded,
    'due_today' => Icons.today_rounded,
    'overdue' => Icons.warning_amber_rounded,
    'upcoming' => Icons.upcoming_rounded,
    'completed' => Icons.task_alt_rounded,
    _ => Icons.history_rounded,
  };

  Widget _queueContent() {
    if (_queueLoading) {
      return const AppCard(
        child: SizedBox(
          height: 300,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        ),
      );
    }
    if (_queueError != null) {
      return AppCard(
        child: AppErrorState(
          title: 'Unable to load the inspection queue',
          message: userFacingError(
            _queueError!,
            fallback:
                'Scheduled inspections could not be loaded. You can still open History to review saved inspections.',
          ),
          technicalDetails: _queueError,
          onRetry: _loadQueue,
          minHeight: 260,
        ),
      );
    }
    if (_queue.isEmpty) return _emptyQueue();

    return ListView.builder(
      itemCount: _queue.length,
      itemBuilder: (_, index) => _queueCard(_queue[index]),
    );
  }

  Widget _emptyQueue() {
    final label = _queueFilters[_queueFilter] ?? 'scheduled';
    final completed = _queueFilter == 'completed';
    return AppCard(
      child: SizedBox(
        height: 250,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.task_alt_rounded : Icons.event_available,
                size: 54,
                color: AppColors.green,
              ),
              const SizedBox(height: 12),
              Text(
                completed ? 'No recent completions' : 'No $label inspections',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                completed
                    ? 'Completed inspections from the last 30 days will appear here.'
                    : _queueFilter == 'action'
                    ? 'There are no overdue or due-today inspections.'
                    : 'Plants will appear here when their schedule matches this view.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _queueCard(Map<String, dynamic> item) {
    final plantId = _intValue(item['plant_id']);
    final classification = _map(item['plant_classification']);
    final name = item['common_name']?.toString().trim().isNotEmpty == true
        ? item['common_name'].toString()
        : classification['common_name']?.toString() ??
              (plantId == null ? 'Unnamed plant' : 'Plant #$plantId');
    final variety = item['variety']?.toString().trim() ?? '';
    final campus =
        item['campus_name']?.toString() ??
        _map(item['campus'])['campus_name']?.toString() ??
        '';
    final due = _parseDate(
      item['next_inspection_due_on'] ?? item['next_inspection_due_date'],
    );
    final last = _parseDate(
      item['last_inspected_on'] ?? item['last_inspection_date'],
    );
    final status = _scheduleStatus(item, due: due, last: last);
    final busy = plantId != null && _openingInspectionPlantId == plantId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = AppBreakpoints.isPhone(constraints.maxWidth);
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _queueAvatar(item, 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen,
                            ),
                          ),
                          if (variety.isNotEmpty)
                            Text(
                              variety,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (campus.isNotEmpty)
                            Text(
                              campus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!compact) _scheduleBadge(status),
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 10),
                  _scheduleBadge(status),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _scheduleDate(
                      icon: Icons.event_rounded,
                      label: 'Next due',
                      value: due == null ? 'Not scheduled' : _date(due),
                    ),
                    _scheduleDate(
                      icon: Icons.fact_check_outlined,
                      label: 'Last inspected',
                      value: last == null ? 'Not inspected' : _date(last),
                    ),
                  ],
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: plantId == null
                      ? null
                      : () => _openQueuePlant(plantId),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View plant'),
                ),
                if (widget.role == 'inspection_team')
                  FilledButton.icon(
                    onPressed: plantId == null || busy
                        ? null
                        : () => _inspectQueuePlant(plantId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(busy ? 'Opening…' : 'Inspect'),
                  ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _queueAvatar(Map<String, dynamic> item, double size) {
    final photo = item['photo_url']?.toString().trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: AppColors.primaryContainer,
        child: photo.isEmpty
            ? const Icon(Icons.eco_rounded, color: AppColors.green)
            : Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.eco_rounded, color: AppColors.green),
              ),
      ),
    );
  }

  Widget _scheduleDate({
    required IconData icon,
    required String label,
    required String value,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.textSecondary),
      const SizedBox(width: 5),
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _scheduleBadge(String status) {
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
      'completed' => (
        'Completed',
        Icons.task_alt_rounded,
        AppColors.green,
        AppColors.primaryContainer,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.fullyRounded,
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
    );
  }

  String _scheduleStatus(
    Map<String, dynamic> item, {
    required DateTime? due,
    required DateTime? last,
  }) {
    final raw = (item['schedule_status'] ?? item['queue_status'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (_queueFilter == 'completed') return 'completed';
    if (raw == 'overdue' ||
        raw == 'due_today' ||
        raw == 'upcoming' ||
        raw == 'completed') {
      return raw!;
    }
    if (due == null) return 'unscheduled';
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(localToday)) return 'overdue';
    if (dueDay == localToday) return 'due_today';
    return 'upcoming';
  }

  DateTime? _parseDate(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  int? _intValue(dynamic value) => value is int
      ? value
      : value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');

  Future<void> _openQueuePlant(int plantId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(
          plantId: plantId,
          userId: widget.userId,
          username: widget.username,
          role: widget.role,
        ),
      ),
    );
    if (mounted) await _refreshAll();
  }

  Future<void> _inspectQueuePlant(int plantId) async {
    if (_openingInspectionPlantId != null) return;
    setState(() => _openingInspectionPlantId = plantId);
    try {
      final plant = await _inspectionService.getPlant(plantId);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InspectionFormScreen(plant: plant, userId: widget.userId),
        ),
      );
      if (!mounted) return;
      if (saved == true) await _refreshAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback:
                    'This inspection could not be opened. Please try again.',
              ),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
    } finally {
      if (mounted) setState(() => _openingInspectionPlantId = null);
    }
  }

  Widget _content() {
    if (_loading) {
      return const AppCard(
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (_error != null) {
      return AppCard(
        child: AppErrorState(
          title: 'Unable to load inspection history',
          message: userFacingError(
            _error!,
            fallback:
                'Inspection records could not be loaded. Please try again.',
          ),
          technicalDetails: _error,
          onRetry: _loadHistory,
          minHeight: 300,
        ),
      );
    }
    if (_inspections.isEmpty) {
      return const AppCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 56,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'No inspections recorded yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Saved plant inspections will appear here.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    final visibleInspections = _visibleInspections;
    return Column(
      children: [
        _filterBar(),
        const SizedBox(height: AppSpacing.lg),
        if (visibleInspections.isEmpty)
          Expanded(child: _noMatchingInspections())
        else
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: visibleInspections.length,
              itemBuilder: (_, index) =>
                  _inspectionCard(visibleInspections[index]),
            ),
          ),
      ],
    );
  }

  Widget _filterBar() => AppCard(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (_, constraints) {
        final healthOptions = _filterOptions('health_status', 'status_name');
        final growthOptions = _filterOptions('growth_status', 'growth_stage');

        if (!AppBreakpoints.isDesktop(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inspectionSearchField(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _mobileFilterButton()),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _hasActiveFilters ? _resetFilters : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(82, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              if (_activeFilterCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (_healthFilter != 'all')
                      _appliedFilterChip(
                        _healthFilter,
                        () => setState(() => _healthFilter = 'all'),
                      ),
                    if (_growthFilter != 'all')
                      _appliedFilterChip(
                        _growthFilter,
                        () => setState(() => _growthFilter = 'all'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              _resultSummary(),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _inspectionSearchField()),
                const SizedBox(width: 10),
                _filterDropdown(
                  label: 'Health',
                  allLabel: 'All health statuses',
                  value: _healthFilter,
                  options: healthOptions,
                  onChanged: (value) => setState(() => _healthFilter = value),
                ),
                const SizedBox(width: 10),
                _filterDropdown(
                  label: 'Growth',
                  allLabel: 'All growth stages',
                  value: _growthFilter,
                  options: growthOptions,
                  onChanged: (value) => setState(() => _growthFilter = value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _resultSummary()),
                if (_activeFilterCount > 0) ...[
                  _activeFilterPill(),
                  const SizedBox(width: 6),
                ],
                TextButton.icon(
                  onPressed: _hasActiveFilters ? _resetFilters : null,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _inspectionSearchField() => TextField(
    controller: _searchController,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: 'Search plant, inspector, or observation',
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded),
            ),
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green, width: 1.4),
      ),
    ),
  );

  Widget _mobileFilterButton() => OutlinedButton(
    onPressed: _openMobileFilters,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: AppColors.darkGreen,
      backgroundColor: _activeFilterCount > 0
          ? AppColors.primaryContainer
          : AppColors.surface,
      side: BorderSide(
        color: _activeFilterCount > 0 ? AppColors.green : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tune_rounded, size: 20),
        const SizedBox(width: 7),
        const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
        if (_activeFilterCount > 0) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_activeFilterCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _resultSummary() => Row(
    children: [
      const Icon(
        Icons.inventory_2_outlined,
        size: 16,
        color: AppColors.textSecondary,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '${_visibleInspections.length} of ${_inspections.length} records',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    ],
  );

  Widget _activeFilterPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.green.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tune_rounded, size: 15, color: AppColors.green),
        const SizedBox(width: 5),
        Text(
          '$_activeFilterCount active',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );

  Widget _appliedFilterChip(String label, VoidCallback onDeleted) => InputChip(
    label: Text(label),
    onDeleted: onDeleted,
    deleteIcon: const Icon(Icons.close_rounded, size: 16),
    deleteIconColor: AppColors.green,
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.darkGreen,
    ),
    backgroundColor: AppColors.primaryContainer,
    side: BorderSide(color: AppColors.green.withValues(alpha: .3)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    visualDensity: VisualDensity.compact,
  );

  Widget _filterDropdown({
    required String label,
    required String allLabel,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    double? width = 190,
  }) {
    final availableOptions = <String>{...options};
    if (value != 'all') availableOptions.add(value);
    final sortedOptions = availableOptions.toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            label == 'Health'
                ? Icons.health_and_safety_outlined
                : Icons.trending_up_rounded,
            color: AppColors.green,
            size: 20,
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green, width: 1.4),
          ),
        ),
        items: [
          DropdownMenuItem(value: 'all', child: Text(allLabel)),
          ...sortedOptions.map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (selected) {
          if (selected != null && selected != value) onChanged(selected);
        },
      ),
    );
  }

  Widget _noMatchingInspections() => AppCard(
    child: SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            const Text(
              'No inspections match your filters',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'Try another search, health status, or growth stage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _inspectionCard(Map<String, dynamic> inspection) {
    final plant = _map(inspection['plant']);
    final classification = _map(plant['plant_classification']);
    final health =
        _map(inspection['health_status'])['status_name']?.toString() ??
        'Unknown';
    final growth =
        _map(inspection['growth_status'])['growth_stage']?.toString() ??
        'Unknown';
    final inspector =
        _map(inspection['users'])['username']?.toString() ??
        'Unknown inspector';
    final observation = inspection['observation']?.toString().trim() ?? '';
    final photo = inspection['photo_url']?.toString() ?? '';
    final name =
        classification['common_name']?.toString() ??
        'Plant #${plant['plant_id']}';
    final date = _date(
      inspection['inspected_at'] ?? inspection['last_inspection_date'],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final compact = AppBreakpoints.isPhone(constraints.maxWidth);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inspectionPhoto(photo, 62),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _inspectionDetails(health, growth, inspector, observation),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inspectionPhoto(photo, 78),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _inspectionDetails(
                        health,
                        growth,
                        inspector,
                        observation,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _inspectionPhoto(String photo, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: AppColors.primaryContainer,
      child: photo.isEmpty
          ? const Icon(
              Icons.fact_check_outlined,
              color: AppColors.green,
              size: 30,
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    ),
  );

  Widget _inspectionDetails(
    String health,
    String growth,
    String inspector,
    String observation,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 7,
        runSpacing: 6,
        children: [
          _chip(health, Icons.health_and_safety_outlined),
          _chip(growth, Icons.trending_up_rounded),
        ],
      ),
      const SizedBox(height: 7),
      Text(
        'Inspected by $inspector',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      if (observation.isNotEmpty) ...[
        const SizedBox(height: 7),
        Text(observation, style: const TextStyle(fontSize: 12)),
      ],
    ],
  );

  Widget _chip(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: AppRadii.fullyRounded,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.green),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Unknown date';
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
}
