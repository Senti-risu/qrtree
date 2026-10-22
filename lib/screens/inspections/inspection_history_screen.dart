import '../../widgets/app_filter_sheet.dart';
import '../../widgets/mobile_search_filter_row.dart';
import '../../widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import '../../utils/search_match.dart';
import '../../widgets/app_workspace_page.dart';
import '../../theme/app_typography.dart';
import '../../widgets/plant_details_presentation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/inspection_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/health_status_label.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/inspection_queue_layout.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_shell.dart';
import '../plants/plant_detail_screen.dart';

class InspectionHistoryScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final String? initialQueueFilter;

  const InspectionHistoryScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.initialQueueFilter,
  });

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  static const _historyPageSize = 250;
  final _supabase = Supabase.instance.client;
  final _inspectionService = InspectionService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _queue = [];
  bool _loading = true;
  bool _queueLoading = true;
  String? _error;
  String? _queueError;
  bool _historyHasMore = false;
  bool _historyLoadingMore = false;
  int _historyFetchedCount = 0;
  String _healthFilter = 'all';
  String _growthFilter = 'all';
  String _queueFilter = 'action';
  int _loadRequestId = 0;
  int _queueRequestId = 0;

  static const _queueFilters = InspectionQueueFilters.filters;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  @override
  void initState() {
    super.initState();
    if (_queueFilters.containsKey(widget.initialQueueFilter)) {
      _queueFilter = widget.initialQueueFilter!;
    }
    _loadHistory();
    _loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleInspections =>
      _matchingInspections(_healthFilter, _growthFilter);

  List<Map<String, dynamic>> _matchingInspections(
    String healthFilter,
    String growthFilter,
  ) {
    final term = _searchController.text.trim().toLowerCase();
    return _inspections.where((inspection) {
      final plant = _map(inspection['plant']);
      final classification = _map(plant['plant_classification']);
      final health = healthStatusLabel(
        _map(inspection['health_status'])['status_name'],
      );
      final growth =
          _map(
            inspection['growth_status'],
          )['growth_stage']?.toString().trim() ??
          'Unknown';

      if (healthFilter != 'all' && health != healthFilter) return false;
      if (growthFilter != 'all' && growth != growthFilter) return false;
      if (term.isEmpty) return true;

      return matchesWordPrefixes([
        classification['common_name'],
        plant['variety'],
        plant['plant_id'],
        _map(inspection['users'])['username'],
        inspection['observation'],
      ], term);
    }).toList();
  }

  List<String> _filterOptions(String relationKey, String valueKey) {
    final values = <String>{};
    for (final records in [_inspections, _queue]) {
      for (final record in records) {
        final value = _recordFilterValue(record, relationKey, valueKey);
        if (value != null && value.isNotEmpty) values.add(value);
      }
    }
    return values.toList()..sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
  }

  String? _recordFilterValue(
    Map<String, dynamic> record,
    String relationKey,
    String valueKey,
  ) {
    final actualRelationKey =
        relationKey == 'growth_stage' && record.containsKey('growth_status')
        ? 'growth_status'
        : relationKey;
    final relation = record[actualRelationKey];
    final value = relation is Map ? relation[valueKey] : relation;
    if (value == null) return null;
    return relationKey == 'health_status'
        ? healthStatusLabel(value).trim()
        : value.toString().trim();
  }

  String _normalizedFilter(
    String current,
    List<Map<String, dynamic>> inspections,
    String relationKey,
    String valueKey,
  ) {
    if (current == 'all') return current;
    final exists = inspections.any((inspection) {
      final value = _map(inspection[relationKey])[valueKey];
      return relationKey == 'health_status'
          ? healthStatusLabel(value) == current
          : value?.toString().trim() == current;
    });
    return exists ? current : 'all';
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _healthFilter != 'all' ||
      _growthFilter != 'all';

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _healthFilter = 'all';
      _growthFilter = 'all';
    });
  }

  Future<void> _loadHistory({bool loadMore = false}) async {
    if (loadMore && (!_historyHasMore || _historyLoadingMore)) return;
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = !loadMore;
      _historyLoadingMore = loadMore;
      if (!loadMore) {
        _error = null;
        _historyFetchedCount = 0;
      }
    });
    try {
      var query = _supabase.from('inspection').select('''
        inspected_at, last_inspection_date, observation, photo_url,
        plant:plant!inner (plant_id, college_id, campus_id, variety, plant_classification (common_name)),
        health_status (status_name), growth_status (growth_stage), users (username)
      ''');
      if ((widget.role == 'inspection_team' ||
              widget.role == 'college_admin') &&
          widget.collegeId != null) {
        query = query.eq('plant.college_id', widget.collegeId!);
      } else if (widget.role == 'campus_admin' && widget.campusId != null) {
        query = query.eq('plant.campus_id', widget.campusId!);
      }

      final rows = List<Map<String, dynamic>>.from(
        await query
            .order('inspected_at', ascending: false)
            .range(
              loadMore ? _historyFetchedCount : 0,
              (loadMore ? _historyFetchedCount : 0) + _historyPageSize - 1,
            ),
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
      final allVisible = loadMore ? [..._inspections, ...visible] : visible;
      final normalizedHealth = _normalizedFilter(
        _healthFilter,
        allVisible,
        'health_status',
        'status_name',
      );
      final normalizedGrowth = _normalizedFilter(
        _growthFilter,
        allVisible,
        'growth_status',
        'growth_stage',
      );
      setState(() {
        _inspections = allVisible;
        _historyFetchedCount =
            (loadMore ? _historyFetchedCount : 0) + rows.length;
        _historyHasMore = rows.length == _historyPageSize;
        _healthFilter = normalizedHealth;
        _growthFilter = normalizedGrowth;
        _loading = false;
        _historyLoadingMore = false;
      });
    } catch (e) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _loading = false;
          _historyLoadingMore = false;
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
        : '${_visibleQueue.length} of ${_queue.length} ${(_queueFilters[_queueFilter] ?? 'scheduled').toLowerCase()}',
    userId: widget.userId,
    username: widget.username,
    role: widget.role,
    campusId: widget.campusId,
    collegeId: widget.collegeId,
    userName: widget.username,
    child: InspectionQueueLayout(
      header: AppBreakpoints.isDesktop(MediaQuery.sizeOf(context).width)
          ? const AppPageHeader(
              title: 'Inspections',
              subtitle:
                  'Prioritize scheduled work and review completed inspections',
            )
          : null,
      filters: InspectionQueueFilters(
        selected: _queueFilter,
        onSelected: _selectQueueFilter,
        search: _inspectionSearchTools(),
      ),
      body: _queueFilter == 'history' ? _content() : _queueContent(),
    ),
  );

  List<Map<String, dynamic>> get _visibleQueue {
    final term = _searchController.text.trim().toLowerCase();
    return _queue.where((item) {
      if (_healthFilter != 'all' &&
          _recordFilterValue(item, 'health_status', 'status_name') !=
              _healthFilter) {
        return false;
      }
      if (_growthFilter != 'all' &&
          _recordFilterValue(item, 'growth_stage', 'growth_stage') !=
              _growthFilter) {
        return false;
      }
      if (term.isEmpty) return true;
      final classification = _map(item['plant_classification']);
      final campus = _map(item['campus']);
      return matchesWordPrefixes([
        item['common_name'],
        classification['common_name'],
        item['variety'],
        item['plant_id'],
        item['campus_name'],
        campus['campus_name'],
      ], term);
    }).toList();
  }

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
          title: 'Unable To Load The Inspection Queue',
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
    final visibleQueue = _visibleQueue;
    if (_queue.isEmpty && !_hasActiveFilters) return _emptyQueue();
    if (visibleQueue.isEmpty) {
      return AppEmptyState(
        title: 'No Matching Inspections',
        message: 'Try a different search, health status, or growth stage.',
        icon: Icons.search_off_rounded,
        action: TextButton(
          onPressed: _resetFilters,
          child: const Text('Reset Filters'),
        ),
      );
    }

    return ListView.builder(
      itemCount: visibleQueue.length,
      itemBuilder: (_, index) => _queueCard(visibleQueue[index]),
    );
  }

  Widget _emptyQueue() => InspectionQueueEmptyState(
    filter: _queueFilter,
    onNext: () => _selectQueueFilter(
      _queueFilter == 'upcoming' || _queueFilter == 'completed'
          ? 'history'
          : 'upcoming',
    ),
  );

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
                                fontSize: AppTypography.caption,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (campus.isNotEmpty)
                            Text(
                              campus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTypography.caption,
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
                      label: 'Next Due',
                      value: due == null ? 'Not Scheduled' : _date(due),
                    ),
                    _scheduleDate(
                      icon: Icons.fact_check_outlined,
                      label: 'Last Inspected',
                      value: last == null ? 'Not Inspected' : _date(last),
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
                  label: const Text('View Plant'),
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
        style: const TextStyle(
          fontSize: AppTypography.caption,
          color: AppColors.textSecondary,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
        ),
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
        'Due Today',
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
        'Not Scheduled',
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
              fontSize: AppTypography.caption,
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
      plantDetailsRoute(
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

  Widget _content() {
    if (_loading) {
      return const AppCard(
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (_error != null) {
      return AppCard(
        child: AppErrorState(
          title: 'Unable To Load Inspection History',
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
                'No Inspections Recorded Yet',
                style: TextStyle(
                  fontSize: AppTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
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
        if (visibleInspections.isEmpty)
          Expanded(child: _noMatchingInspections())
        else
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: visibleInspections.length + (_historyHasMore ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == visibleInspections.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _historyLoadingMore
                            ? null
                            : () => _loadHistory(loadMore: true),
                        icon: _historyLoadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _historyLoadingMore
                              ? 'Loading…'
                              : 'Load Older Inspections',
                        ),
                      ),
                    ),
                  );
                }
                return _inspectionCard(visibleInspections[index]);
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openMobileFilters() async {
    var health = _healthFilter;
    var growth = _growthFilter;
    final healthOptions = _filterOptions('health_status', 'status_name');
    final growthOptions = _filterOptions('growth_stage', 'growth_stage');
    Widget group(
      String title,
      String allLabel,
      List<String> options,
      String selected,
      ValueChanged<String> onSelect,
      String Function(String) labelOf,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(allLabel),
              selected: selected == 'all',
              onSelected: (_) => onSelect('all'),
            ),
            for (final option in options)
              ChoiceChip(
                label: Text(labelOf(option)),
                selected: selected == option,
                onSelected: (_) => onSelect(option),
              ),
          ],
        ),
      ],
    );
    final applied = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AppFilterSheet(
          title: 'Filter Inspections',
          applyLabel: 'Apply Filters',
          onReset: () => setSheetState(() {
            health = 'all';
            growth = 'all';
          }),
          onApply: () => Navigator.pop(sheetContext, (health, growth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              group(
                'Health',
                'All Health',
                healthOptions,
                health,
                (value) => setSheetState(() => health = value),
                healthStatusLabel,
              ),
              const SizedBox(height: AppSpacing.lg),
              group(
                'Growth',
                'All Growth',
                growthOptions,
                growth,
                (value) => setSheetState(() => growth = value),
                (value) => value,
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == null || !mounted) return;
    setState(() {
      _healthFilter = applied.$1;
      _growthFilter = applied.$2;
    });
  }

  Widget _inspectionSearchTools() => LayoutBuilder(
    builder: (context, constraints) {
      final healthOptions = _filterOptions('health_status', 'status_name');
      final growthOptions = _filterOptions('growth_stage', 'growth_stage');
      final isWide = constraints.maxWidth >= 980;
      final filters = Row(
        children: [
          Expanded(
            child: _filterDropdown(
              label: 'Health',
              allLabel: 'All Health',
              value: _healthFilter,
              options: healthOptions,
              onChanged: (value) => setState(() => _healthFilter = value),
              width: null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _filterDropdown(
              label: 'Growth',
              allLabel: 'All Growth',
              value: _growthFilter,
              options: growthOptions,
              onChanged: (value) => setState(() => _growthFilter = value),
              width: null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            Row(
              children: [
                Expanded(flex: 3, child: _inspectionSearchField()),
                const SizedBox(width: 12),
                SizedBox(width: 430, child: filters),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Reset search and filters',
                  onPressed: _hasActiveFilters ? _resetFilters : null,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            )
          else ...[
            MobileSearchFilterRow(
              search: _inspectionSearchField(),
              onFilter: _openMobileFilters,
              activeCount:
                  (_healthFilter != 'all' ? 1 : 0) +
                  (_growthFilter != 'all' ? 1 : 0),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _queueFilter == 'history'
                    ? '${_visibleInspections.length} of ${_inspections.length} records'
                    : '${_visibleQueue.length} of ${_queue.length} plants',
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _inspectionSearchField() => AppSearchField(
    controller: _searchController,
    suggestions: _queueFilter == 'history'
        ? _inspections
              .expand(
                (inspection) => [
                  _map(
                    _map(inspection['plant'])['plant_classification'],
                  )['common_name'],
                  _map(inspection['users'])['username'],
                  inspection['observation'],
                ],
              )
              .whereType<Object>()
              .map((value) => value.toString())
        : _queue
              .expand(
                (item) => [
                  item['common_name'],
                  _map(item['plant_classification'])['common_name'],
                  item['variety'],
                  item['campus_name'],
                  item['plant_id'],
                ],
              )
              .whereType<Object>()
              .map((value) => value.toString()),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: _queueFilter == 'history'
          ? 'Search plant, inspector, or observation'
          : 'Search plant, variety, campus, or ID',
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear Search',
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded),
            ),
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: kMobileSearchVerticalPadding,
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
              child: Text(
                label == 'Health' ? healthStatusLabel(option) : option,
                overflow: TextOverflow.ellipsis,
              ),
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
              'No Inspections Match Your Filters',
              style: TextStyle(
                fontSize: AppTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
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
              label: const Text('Reset Filters'),
            ),
            if (_historyHasMore)
              TextButton.icon(
                onPressed: _historyLoadingMore
                    ? null
                    : () => _loadHistory(loadMore: true),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load Older Inspections'),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _inspectionCard(Map<String, dynamic> inspection) {
    final plant = _map(inspection['plant']);
    final classification = _map(plant['plant_classification']);
    final health = healthStatusLabel(
      _map(inspection['health_status'])['status_name'],
    );
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
                                fontSize: AppTypography.caption,
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
                              fontSize: AppTypography.caption,
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
        style: const TextStyle(
          fontSize: AppTypography.caption,
          color: AppColors.textSecondary,
        ),
      ),
      if (observation.isNotEmpty) ...[
        const SizedBox(height: 7),
        Text(observation, style: const TextStyle(fontSize: AppTypography.body)),
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
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
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
