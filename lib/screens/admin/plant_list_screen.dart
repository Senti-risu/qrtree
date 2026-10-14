import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_page_header.dart';
import '../plants/plant_detail_screen.dart';
import 'plant_service.dart';

class PlantListScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final String? initialHealthFilter;

  const PlantListScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.initialHealthFilter,
  });

  @override
  State<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  final _supabase = Supabase.instance.client;
  final _plantService = PlantService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _plants = [];
  bool _loading = true;
  String? _error;
  String _healthFilter = 'All';
  String _recordFilter = 'active';

  RoleCapabilities get _capabilities => RoleCapabilities.fromValue(widget.role);

  @override
  void initState() {
    super.initState();
    final requestedFilter = widget.initialHealthFilter;
    if (requestedFilter != null && _healthOptions.contains(requestedFilter)) {
      _healthFilter = requestedFilter;
    }
    _loadPlants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _supabase
          .from('plant')
          .select('''
        plant_id, variety, date_planted, tree_planter, photo_url, created_at, campus_id, college_id,
        archived_at, archive_reason,
        plant_classification (common_name, scientific_name, plant_type),
        campus (campus_name), college (college_name),
        growth_status (growth_stage), health_status (status_name),
        qr_tag:qr_tag!plant_qr_tag_id_fkey(qr_code_string)
      ''');
      if (widget.role == 'campus_admin' && widget.campusId != null) {
        query = query.eq('campus_id', widget.campusId!);
      } else if ((widget.role == 'college_admin' ||
              widget.role == 'inspection_team') &&
          widget.collegeId != null) {
        query = query.eq('college_id', widget.collegeId!);
      }
      final rows = List<Map<String, dynamic>>.from(
        await query.order('created_at', ascending: false),
      );
      try {
        final plantIds = rows.map((row) => row['plant_id'] as int).toList();
        if (plantIds.isNotEmpty) {
          final inspections = await _supabase
              .from('inspection')
              .select('plant_id, inspected_at, last_inspection_date')
              .inFilter('plant_id', plantIds);
          for (final plant in rows) {
            plant['plant_inspection'] = inspections
                .where((item) => item['plant_id'] == plant['plant_id'])
                .toList();
          }
        }
      } catch (_) {
        for (final plant in rows) {
          plant['plant_inspection'] = <Map<String, dynamic>>[];
        }
      }
      if (!mounted) return;
      setState(() {
        _plants = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  String _health(Map<String, dynamic> plant) {
    final value =
        _map(plant['health_status'])['status_name']?.toString().toLowerCase() ??
        '';
    if (value == 'alive' || value == 'healthy') return 'Healthy';
    if (value == 'dying' || value == 'at risk') return 'Needs attention';
    if (value == 'dead') return 'Dead';
    return 'Unknown';
  }

  List<Map<String, dynamic>> get _searchMatchedPlants {
    final term = _searchController.text.trim().toLowerCase();
    return _plants.where((plant) {
      final archived = plant['archived_at'] != null;
      if (_recordFilter == 'active' && archived) return false;
      if (_recordFilter == 'archived' && !archived) return false;
      final classification = _map(plant['plant_classification']);
      final text = [
        plant['plant_id'],
        _tagId(plant),
        plant['variety'],
        plant['tree_planter'],
        classification['common_name'],
        classification['scientific_name'],
        classification['plant_type'],
        _map(plant['campus'])['campus_name'],
        _map(plant['college'])['college_name'],
      ].join(' ').toLowerCase();
      return term.isEmpty || text.contains(term);
    }).toList();
  }

  List<Map<String, dynamic>> get _visiblePlants {
    final plants = _searchMatchedPlants;
    if (_healthFilter == 'All') return plants;
    return plants.where((plant) => _health(plant) == _healthFilter).toList();
  }

  bool get _hasActiveFilters =>
      _healthFilter != 'All' ||
      _searchController.text.trim().isNotEmpty ||
      _recordFilter != 'active';

  int get _activeFilterCount => [
    _healthFilter != 'All',
    _searchController.text.trim().isNotEmpty,
    _recordFilter != 'active',
  ].where((active) => active).length;

  int get _hiddenFilterCount => _healthFilter == 'All' ? 0 : 1;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _healthFilter = 'All';
      _recordFilter = 'active';
    });
  }

  int get _recordCount => _plants.where((plant) {
    final archived = plant['archived_at'] != null;
    return _recordFilter == 'archived' ? archived : !archived;
  }).length;

  Map<String, dynamic> get _arguments => {
    'user_id': widget.userId,
    'username': widget.username,
    'role': widget.role,
    'campus_id': widget.campusId,
    'college_id': widget.collegeId,
  };

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/plant-list',
      mobileTitle: 'Plant Records',
      mobileSubtitle:
          '$_recordCount ${_recordFilter == 'archived' ? 'archived' : 'active'} plants',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      campusId: widget.campusId,
      collegeId: widget.collegeId,
      userName: widget.username,
      onRefresh: _loadPlants,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            _header(),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (!isDesktop && _capabilities.canRegisterPlants) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/register-plant',
                  arguments: _arguments,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Register a plant'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _filters(),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _header() => AppPageHeader(
    title: 'Plant Records',
    subtitle: 'Browse and monitor registered campus plants',
    trailing: _capabilities.canRegisterPlants
        ? FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              '/register-plant',
              arguments: _arguments,
            ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Register Plant'),
          )
        : null,
  );

  Widget _filters() => AppCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mobile = !AppBreakpoints.isDesktop(constraints.maxWidth);
        return mobile ? _mobileFilters() : _desktopFilters();
      },
    ),
  );

  Widget _desktopFilters() {
    final plants = _searchMatchedPlants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.filterAccent,
                borderRadius: AppRadii.small,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find plants',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Search records or narrow the list by health status',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_capabilities.canRestorePlants) ...[
              _recordSelector(),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (_hasActiveFilters) ...[
              _activeBadge(_activeFilterCount),
              const SizedBox(width: 6),
              TextButton(onPressed: _clearFilters, child: const Text('Reset')),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 4, child: _searchField()),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in _healthOptions) ...[
                      if (value != _healthOptions.first)
                        const SizedBox(width: AppSpacing.sm),
                      _healthChoice(
                        value,
                        _healthCount(value, plants),
                        _healthFilter,
                        (selected) => setState(() => _healthFilter = selected),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _resultSummary(),
      ],
    );
  }

  Widget _mobileFilters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_capabilities.canRestorePlants) ...[
        _recordSelector(compact: true),
        const SizedBox(height: AppSpacing.md),
      ],
      Row(
        children: [
          Expanded(child: _searchField()),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _showHealthFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: BorderSide(
                  color: _hiddenFilterCount > 0
                      ? AppColors.green
                      : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.medium,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 19),
                  const SizedBox(width: 6),
                  const Text(
                    'Filter',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (_hiddenFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    _countBadge(_hiddenFilterCount),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      if (_healthFilter != 'All') ...[
        const SizedBox(height: AppSpacing.sm),
        InputChip(
          label: Text('Health: $_healthFilter'),
          avatar: Icon(
            _healthIcon(_healthFilter),
            size: 17,
            color: _healthColor(_healthFilter),
          ),
          onDeleted: () => setState(() => _healthFilter = 'All'),
          deleteIconColor: AppColors.textSecondary,
          backgroundColor: AppColors.primaryContainer,
          side: const BorderSide(color: AppColors.borderStrong),
          labelStyle: const TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      _resultSummary(),
    ],
  );

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: (_) => setState(() {}),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search name, tag, variety…',
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
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: AppBorders.subtleSide,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: AppBorders.subtleSide,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: AppBorders.focusedSide,
      ),
    ),
  );

  Widget _resultSummary() => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          '${_visiblePlants.length} of $_recordCount plants shown',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
      if (_hasActiveFilters)
        TextButton(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Clear all'),
        ),
    ],
  );

  static const _healthOptions = [
    'All',
    'Healthy',
    'Needs attention',
    'Dead',
    'Unknown',
  ];

  Widget _recordSelector({bool compact = false}) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final option in const [
          ('active', 'Active', Icons.eco_outlined),
          ('archived', 'Archived', Icons.archive_outlined),
        ])
          if (compact)
            Expanded(child: _recordChoice(option.$1, option.$2, option.$3))
          else
            _recordChoice(option.$1, option.$2, option.$3),
      ],
    ),
  );

  Widget _recordChoice(String value, String label, IconData icon) {
    final selected = _recordFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() {
        _recordFilter = value;
        _healthFilter = 'All';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.softShadow,
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.green : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.darkGreen : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _healthCount(String value, List<Map<String, dynamic>> plants) =>
      value == 'All'
      ? plants.length
      : plants.where((plant) => _health(plant) == value).length;

  Color _healthColor(String value) => value == 'Needs attention'
      ? AppColors.warningAccent
      : value == 'Dead'
      ? AppColors.danger
      : value == 'Unknown'
      ? AppColors.textSecondary
      : AppColors.green;

  IconData _healthIcon(String value) => value == 'All'
      ? Icons.apps_rounded
      : value == 'Healthy'
      ? Icons.eco_rounded
      : value == 'Needs attention'
      ? Icons.warning_amber_rounded
      : value == 'Dead'
      ? Icons.local_florist_outlined
      : Icons.help_outline_rounded;

  Widget _healthChoice(
    String value,
    int count,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final active = value == selected;
    final accent = _healthColor(value);
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        _healthIcon(value),
        size: 17,
        color: active ? accent : AppColors.textSecondary,
      ),
      label: Text('$value  $count'),
      selected: active,
      onSelected: (_) => onSelected(value),
      selectedColor: accent.withValues(alpha: .11),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: active ? accent : AppColors.border,
        width: active ? 1.3 : 1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: active ? AppColors.darkGreen : AppColors.textSecondary,
      ),
    );
  }

  Widget _activeBadge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.warningContainer,
      borderRadius: AppRadii.fullyRounded,
      border: Border.all(color: AppColors.warningAccent),
    ),
    child: Text(
      '$count active',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.warning,
      ),
    ),
  );

  Widget _countBadge(int count) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: const BoxDecoration(
      color: AppColors.filterAccent,
      shape: BoxShape.circle,
    ),
    child: Text(
      count.toString(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );

  Future<void> _showHealthFilters() async {
    var pendingHealth = _healthFilter;
    final plants = _searchMatchedPlants;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadii.medium,
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter plants',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Choose a health status',
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
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HEALTH STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _healthOptions
                          .map(
                            (value) => _healthChoice(
                              value,
                              _healthCount(value, plants),
                              pendingHealth,
                              (selected) =>
                                  updateSheet(() => pendingHealth = selected),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            updateSheet(() => pendingHealth = 'All'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          setState(() => _healthFilter = pendingHealth);
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.green,
                        ),
                        child: Text(
                          'Show ${_healthCount(pendingHealth, plants)} plants',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const AppCard(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      );
    }
    if (_error != null) {
      return AppCard(
        child: AppErrorState(
          title: 'Unable to load plants',
          message: userFacingError(
            _error!,
            fallback:
                'Your plant records could not be loaded. Please try again.',
          ),
          technicalDetails: _error,
          onRetry: _loadPlants,
        ),
      );
    }
    final plants = _visiblePlants;
    if (plants.isEmpty) {
      return AppCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_florist_outlined,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _recordCount == 0
                    ? _recordFilter == 'archived'
                          ? 'No archived plants'
                          : 'No plants registered yet'
                    : 'No plants match your filters',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_recordCount > 0 && _hasActiveFilters) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isPhone(constraints.maxWidth)) {
          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: plants.length,
            itemBuilder: (context, index) => _plantCard(plants[index]),
          );
        }
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: _plantTable(plants),
        );
      },
    );
  }

  Widget _plantCard(Map<String, dynamic> plant) {
    final classification = _map(plant['plant_classification']);
    final health = _health(plant);
    final archived = plant['archived_at'] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openPlant(plant),
        borderRadius: BorderRadius.circular(14),
        child: AppCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _plantAvatar(plant, 56),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classification['common_name']?.toString() ??
                          'Unnamed plant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      classification['scientific_name']?.toString() ??
                          'Scientific name unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _map(plant['campus'])['campus_name']?.toString() ??
                                'No campus',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (archived && _capabilities.canRestorePlants)
                IconButton.outlined(
                  tooltip: 'Restore plant',
                  onPressed: () => _restorePlant(plant),
                  icon: const Icon(Icons.unarchive_outlined),
                )
              else
                _statusChip(health),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plantTable(List<Map<String, dynamic>> plants) => AppCard(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _recordFilter == 'archived'
              ? 'Archived Plants'
              : _healthFilter == 'All'
              ? 'All Plants'
              : '$_healthFilter Plants',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.background,
              ),
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('PLANT NAME')),
                DataColumn(label: Text('TAG ID')),
                DataColumn(label: Text('VARIETY')),
                DataColumn(label: Text('TREE PLANTER')),
                DataColumn(label: Text('STAGE')),
                DataColumn(label: Text('HEALTH')),
                DataColumn(label: Text('DATE PLANTED')),
                DataColumn(label: Text('LAST INSPECTED')),
                DataColumn(label: Text('ACTION')),
              ],
              rows: plants.map((plant) {
                final classification = _map(plant['plant_classification']);
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          _plantAvatar(plant, 38),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 130,
                            child: Text(
                              classification['common_name']?.toString() ??
                                  'Unnamed plant',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(_tagId(plant))),
                    DataCell(Text(plant['variety']?.toString() ?? '—')),
                    DataCell(Text(plant['tree_planter']?.toString() ?? '—')),
                    DataCell(
                      Text(
                        _map(
                              plant['growth_status'],
                            )['growth_stage']?.toString() ??
                            '—',
                      ),
                    ),
                    DataCell(_statusChip(_health(plant))),
                    DataCell(Text(_date(plant['date_planted']))),
                    DataCell(Text(_lastInspected(plant))),
                    DataCell(
                      plant['archived_at'] != null &&
                              _capabilities.canRestorePlants
                          ? OutlinedButton.icon(
                              onPressed: () => _restorePlant(plant),
                              icon: const Icon(
                                Icons.unarchive_outlined,
                                size: 18,
                              ),
                              label: const Text('Restore'),
                            )
                          : TextButton.icon(
                              onPressed: () => _openPlant(plant),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('View'),
                            ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    ),
  );

  String _tagId(Map<String, dynamic> plant) {
    final raw = _map(plant['qr_tag'])['qr_code_string']?.toString();
    return raw == null || raw.trim().isEmpty ? 'Not assigned' : raw;
  }

  String _date(dynamic value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
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

  String _lastInspected(Map<String, dynamic> plant) {
    final inspections = plant['plant_inspection'];
    if (inspections is! List || inspections.isEmpty) return 'Not inspected';
    final dates =
        inspections
            .map((row) {
              final item = _map(row);
              return DateTime.tryParse(
                (item['inspected_at'] ?? item['last_inspection_date'])
                        ?.toString() ??
                    '',
              );
            })
            .whereType<DateTime>()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return dates.isEmpty
        ? 'Not inspected'
        : _date(dates.first.toIso8601String());
  }

  Future<void> _openPlant(Map<String, dynamic> plant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(
          plantId: plant['plant_id'] as int,
          userId: widget.userId,
          username: widget.username,
          role: widget.role,
        ),
      ),
    );
    _loadPlants();
  }

  Future<void> _restorePlant(Map<String, dynamic> plant) async {
    final plantId = plant['plant_id'] as int?;
    if (plantId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this plant?'),
        content: const Text(
          'The plant will return to the active records and keep its existing history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _plantService.restorePlant(plantId: plantId);
      await _loadPlants();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plant restored to active records.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'The plant could not be restored. Try again.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _plantAvatar(Map<String, dynamic> plant, double size) {
    final url = plant['photo_url']?.toString() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: AppColors.primaryContainer,
        child: url.isEmpty
            ? const Icon(Icons.local_florist_rounded, color: AppColors.green)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.green,
                ),
              ),
      ),
    );
  }

  Widget _statusChip(String label) {
    final foreground = label == 'Healthy'
        ? AppColors.green
        : label == 'Needs attention'
        ? AppColors.warning
        : label == 'Dead'
        ? AppColors.danger
        : AppColors.textSecondary;
    final background = label == 'Healthy'
        ? AppColors.primaryContainer
        : label == 'Needs attention'
        ? AppColors.warningContainer
        : label == 'Dead'
        ? AppColors.dangerContainer
        : AppColors.surfaceDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.fullyRounded,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
