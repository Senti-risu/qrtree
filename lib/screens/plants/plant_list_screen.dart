import '../../widgets/app_search_field.dart';
import '../../utils/search_match.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_workspace_page.dart';
import '../../theme/app_typography.dart';
import '../../widgets/plant_details_presentation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/health_status_label.dart';
import '../../widgets/app_card.dart';
import '../../widgets/compact_filter_panel.dart';
import '../../widgets/app_filter_sheet.dart';
import '../../widgets/plant_summary_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_page_header.dart';
import 'plant_detail_screen.dart';
import '../../services/plant_service.dart';

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
  static const _desktopPageSize = 25;
  final _supabase = Supabase.instance.client;
  final _plantService = PlantService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _campuses = [];
  bool _loading = true;
  String? _error;
  int _desktopPage = 0;
  String _healthFilter = 'All';
  int? _campusFilter;
  String _recordFilter = 'active';

  RoleCapabilities get _capabilities => RoleCapabilities.fromValue(widget.role);
  bool get _canFilterCampus => widget.role == 'university_admin';

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
        last_inspected_on,
        archived_at, archive_reason,
        planting_location_type,
        planting_campus:campus!plant_planting_campus_id_fkey(campus_name),
        town(town_name), barangay(barangay_name),
        plant_classification (common_name, scientific_name, plant_type),
        campus:campus!plant_campus_id_fkey (campus_name), college (college_name),
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
      final campusesFuture = _canFilterCampus
          ? _plantService.getCampuses()
          : Future.value(<Map<String, dynamic>>[]);
      final rows = List<Map<String, dynamic>>.from(
        await query.order('created_at', ascending: false),
      );
      final campuses = await campusesFuture;
      if (!mounted) return;
      setState(() {
        _plants = rows;
        _campuses = campuses;
        _desktopPage = 0;
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
    return healthStatusLabel(_map(plant['health_status'])['status_name']);
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
      return matchesWordPrefixes([text], term);
    }).toList();
  }

  List<Map<String, dynamic>> get _visiblePlants {
    final plants = _campusMatchedPlants;
    if (_healthFilter == 'All') return plants;
    return plants.where((plant) => _health(plant) == _healthFilter).toList();
  }

  List<Map<String, dynamic>> get _campusMatchedPlants {
    final plants = _searchMatchedPlants;
    if (_campusFilter == null) return plants;
    return plants
        .where(
          (plant) =>
              int.tryParse(plant['campus_id']?.toString() ?? '') ==
              _campusFilter,
        )
        .toList();
  }

  List<MapEntry<int, String>> get _campusOptions {
    final campuses = <int, String>{};
    for (final campus in _campuses) {
      final campusId = int.tryParse(campus['campus_id']?.toString() ?? '');
      if (campusId == null) continue;
      final campusName = campus['campus_name']?.toString().trim() ?? '';
      campuses[campusId] = campusName.isEmpty ? 'Campus $campusId' : campusName;
    }
    return campuses.entries
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList()
      ..sort(
        (left, right) =>
            left.value.toLowerCase().compareTo(right.value.toLowerCase()),
      );
  }

  String _campusName(int campusId) {
    for (final campus in _campusOptions) {
      if (campus.key == campusId) return campus.value;
    }
    return 'Unknown';
  }

  bool get _hasActiveFilters =>
      _healthFilter != 'All' ||
      _campusFilter != null ||
      _searchController.text.trim().isNotEmpty ||
      _recordFilter != 'active';

  int get _activeFilterCount => [
    _healthFilter != 'All',
    _campusFilter != null,
    _searchController.text.trim().isNotEmpty,
    _recordFilter != 'active',
  ].where((active) => active).length;

  int get _hiddenFilterCount =>
      (_healthFilter == 'All' ? 0 : 1) + (_campusFilter == null ? 0 : 1);

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _desktopPage = 0;
      _healthFilter = 'All';
      _campusFilter = null;
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
    final visiblePlants = _visiblePlants;
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
      child: isDesktop
          ? AppWorkspacePage(
              header: _header(),
              tools: _filters(),
              body: _content(),
            )
          : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _filters()),
                if (_capabilities.canRegisterPlants)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    sliver: SliverToBoxAdapter(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/register-plant',
                          arguments: _arguments,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Register A Plant'),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                if (_loading || _error != null || visiblePlants.isEmpty)
                  SliverToBoxAdapter(child: _content())
                else
                  SliverList.builder(
                    itemCount: visiblePlants.length,
                    itemBuilder: (_, index) => _plantCard(visiblePlants[index]),
                  ),
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

  Widget _filters() => AppToolbarCard(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mobile = !AppBreakpoints.isDesktop(constraints.maxWidth);
        return mobile
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: _mobileFilters(),
              )
            : _desktopFilters();
      },
    ),
  );

  Widget _desktopFilters() {
    final plants = _campusMatchedPlants;
    return CompactFilterPanel(
      search: _searchField(),
      controls: [
        if (_capabilities.canRestorePlants) _recordSelector(),
        if (_canFilterCampus) _campusSelector(),
        if (_hasActiveFilters)
          TextButton(onPressed: _clearFilters, child: const Text('Reset')),
      ],
      choices: [
        for (final value in _healthOptions)
          _healthChoice(
            value,
            _healthCount(value, plants),
            _healthFilter,
            (selected) => setState(() {
              _desktopPage = 0;
              _healthFilter = selected;
            }),
          ),
        if (_hasActiveFilters) _activeBadge(_activeFilterCount),
      ],
      resultSummary: '${_visiblePlants.length} of $_recordCount plants shown',
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
          const SizedBox(width: AppSpacing.md),
          IconButton(
            onPressed: _showHealthFilters,
            tooltip: 'Filters',
            style: IconButton.styleFrom(
              minimumSize: const Size(56, 56),
              foregroundColor: AppColors.darkGreen,
              backgroundColor: _hiddenFilterCount > 0
                  ? AppColors.primaryContainer
                  : AppColors.surface,
              side: BorderSide(
                color: _hiddenFilterCount > 0
                    ? AppColors.green
                    : AppColors.border,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.medium,
              ),
            ),
            icon: Badge(
              isLabelVisible: _hiddenFilterCount > 0,
              label: Text('$_hiddenFilterCount'),
              child: const Icon(Icons.tune_rounded),
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
          onDeleted: () => setState(() {
            _desktopPage = 0;
            _healthFilter = 'All';
          }),
          deleteIconColor: AppColors.textSecondary,
          backgroundColor: AppColors.primaryContainer,
          side: const BorderSide(color: AppColors.borderStrong),
          labelStyle: const TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      if (_campusFilter != null) ...[
        const SizedBox(height: AppSpacing.sm),
        InputChip(
          label: Text('Campus: ${_campusName(_campusFilter!)}'),
          onDeleted: () => setState(() {
            _desktopPage = 0;
            _campusFilter = null;
          }),
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

  Widget _searchField() => AppSearchField(
    controller: _searchController,
    suggestions: _plants
        .expand(
          (plant) => [
            _map(plant['plant_classification'])['common_name'],
            _map(plant['plant_classification'])['scientific_name'],
            plant['variety'],
            _tagId(plant),
          ],
        )
        .whereType<Object>()
        .map((value) => value.toString()),
    onChanged: (_) => setState(() => _desktopPage = 0),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search name, tag, variety…',
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear Search',
              onPressed: () {
                _searchController.clear();
                setState(() => _desktopPage = 0);
              },
              icon: const Icon(Icons.close_rounded),
            ),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
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
          child: const Text('Clear All'),
        ),
    ],
  );

  static const _healthOptions = ['All', 'Healthy', 'Needs Attention', 'Dead'];

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
        _desktopPage = 0;
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

  Color _healthColor(String value) => value == 'Needs Attention'
      ? AppColors.warningAccent
      : value == 'Dead'
      ? AppColors.danger
      : AppColors.green;

  IconData _healthIcon(String value) => value == 'All'
      ? Icons.apps_rounded
      : value == 'Healthy'
      ? Icons.eco_rounded
      : value == 'Needs Attention'
      ? Icons.warning_amber_rounded
      : Icons.cancel_outlined;

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

  Widget _campusSelector({
    int? selectedCampus,
    bool useSelectedCampus = false,
    ValueChanged<int?>? onChanged,
  }) {
    final options = _campusOptions;
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<int>(
        initialValue: useSelectedCampus ? selectedCampus : _campusFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Campus',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: AppRadii.medium,
            borderSide: AppBorders.subtleSide,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.medium,
            borderSide: AppBorders.subtleSide,
          ),
        ),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('All campuses')),
          ...options.map(
            (campus) => DropdownMenuItem<int>(
              value: campus.key,
              child: Text(campus.value, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged:
            onChanged ??
            (value) => setState(() {
              _desktopPage = 0;
              _campusFilter = value;
            }),
      ),
    );
  }

  Future<void> _showHealthFilters() async {
    var pendingHealth = _healthFilter;
    var pendingCampus = _campusFilter;
    final plants = _searchMatchedPlants;
    List<Map<String, dynamic>> filteredPlants() {
      final campusPlants = pendingCampus == null
          ? plants
          : plants
                .where(
                  (plant) =>
                      int.tryParse(plant['campus_id']?.toString() ?? '') ==
                      pendingCampus,
                )
                .toList();
      return pendingHealth == 'All'
          ? campusPlants
          : campusPlants
                .where((plant) => _health(plant) == pendingHealth)
                .toList();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: StatefulBuilder(
            builder: (context, updateSheet) => AppFilterSheet(
              title: 'Filter Plants',
              applyLabel: 'Apply · ${filteredPlants().length} plants',
              onReset: () => updateSheet(() {
                pendingHealth = 'All';
                pendingCampus = null;
              }),
              onApply: () {
                setState(() {
                  _desktopPage = 0;
                  _healthFilter = pendingHealth;
                  _campusFilter = pendingCampus;
                });
                Navigator.pop(dialogContext);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_canFilterCampus) ...[
                    const Text('Campus'),
                    const SizedBox(height: AppSpacing.sm),
                    _campusSelector(
                      selectedCampus: pendingCampus,
                      useSelectedCampus: true,
                      onChanged: (selected) =>
                          updateSheet(() => pendingCampus = selected),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const Text('Health Status'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _healthOptions
                        .map(
                          (value) => _healthChoice(
                            value,
                            pendingCampus == null
                                ? _healthCount(value, plants)
                                : value == 'All'
                                ? plants
                                      .where(
                                        (plant) =>
                                            int.tryParse(
                                              plant['campus_id']?.toString() ??
                                                  '',
                                            ) ==
                                            pendingCampus,
                                      )
                                      .length
                                : plants
                                      .where(
                                        (plant) =>
                                            int.tryParse(
                                                  plant['campus_id']
                                                          ?.toString() ??
                                                      '',
                                                ) ==
                                                pendingCampus &&
                                            _health(plant) == value,
                                      )
                                      .length,
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
          ),
        ),
      ),
    );
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
          title: 'Unable To Load Plants',
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
      return AppEmptyState(
        title: _recordCount == 0
            ? _recordFilter == 'archived'
                  ? 'No archived plants'
                  : 'No plants registered yet'
            : 'No plants match your filters',
        message: _recordCount == 0
            ? 'Plant records will appear here when available.'
            : 'Try another search or clear your filters.',
        icon: Icons.eco_outlined,
        action: _recordCount > 0 && _hasActiveFilters
            ? OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear Filters'),
              )
            : null,
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
    final campus = _map(plant['campus'])['campus_name']?.toString();
    final college = _map(plant['college'])['college_name']?.toString();
    final locationType = plant['planting_location_type'];
    final plantingCampus = _map(
      plant['planting_campus'],
    )['campus_name']?.toString();
    final town = _map(plant['town'])['town_name']?.toString();
    final barangay = _map(plant['barangay'])['barangay_name']?.toString();
    final physicalLocation = [
      if (locationType == 'inside' && plantingCampus != null) plantingCampus,
      if (locationType == 'outside') 'Outside Campus',
      ?barangay,
      ?town,
    ].join(', ');
    return PlantSummaryCard(
      name: classification['common_name']?.toString() ?? 'Unnamed plant',
      plantType: classification['plant_type']?.toString() ?? 'Plant',
      role: widget.role,
      campus: campus,
      college: college,
      scientificName:
          classification['scientific_name']?.toString() ??
          'Scientific name unavailable',
      plantedAt: physicalLocation.isEmpty
          ? 'Location not recorded'
          : physicalLocation,
      photo: _plantAvatar(plant, 44),
      status: _statusChip(_health(plant)),
      trailing: plant['archived_at'] != null && _capabilities.canRestorePlants
          ? IconButton.outlined(
              tooltip: 'Restore Plant',
              onPressed: () => _restorePlant(plant),
              icon: const Icon(Icons.unarchive_outlined),
            )
          : null,
      onTap: () => _openPlant(plant),
    );
  }

  Widget _plantTable(List<Map<String, dynamic>> plants) {
    final pageCount = (plants.length / _desktopPageSize).ceil();
    final page = _desktopPage.clamp(0, pageCount - 1);
    final firstIndex = page * _desktopPageSize;
    final pagePlants = plants.skip(firstIndex).take(_desktopPageSize).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              fontSize: AppTypography.sectionTitle,
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
                showCheckboxColumn: false,
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.background,
                ),
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('PLANT NAME')),
                  DataColumn(label: Text('TAG ID')),
                  DataColumn(label: Text('PLANT TYPE')),
                  DataColumn(label: Text('CAMPUS')),
                  DataColumn(label: Text('STAGE')),
                  DataColumn(label: Text('HEALTH')),
                  DataColumn(label: Text('DATE PLANTED')),
                  DataColumn(label: Text('LAST INSPECTION')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: pagePlants.map((plant) {
                  final classification = _map(plant['plant_classification']);
                  return DataRow(
                    onSelectChanged: (_) => _openPlant(plant),
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
                      DataCell(
                        Text(classification['plant_type']?.toString() ?? '—'),
                      ),
                      DataCell(
                        Text(
                          _map(plant['campus'])['campus_name']?.toString() ??
                              '—',
                        ),
                      ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${firstIndex + 1}–${firstIndex + pagePlants.length} of ${plants.length} plants',
                  style: const TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0
                    ? () => setState(() => _desktopPage = page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${page + 1} / $pageCount'),
              IconButton(
                tooltip: 'Next page',
                onPressed: page + 1 < pageCount
                    ? () => setState(() => _desktopPage = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tagId(Map<String, dynamic> plant) {
    final raw = _map(plant['qr_tag'])['qr_code_string']?.toString();
    return raw == null || raw.trim().isEmpty ? 'Not Assigned' : raw;
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
    final latestInspection = plant['last_inspected_on'];
    if (latestInspection != null) return _date(latestInspection);
    final inspections = plant['plant_inspection'];
    if (inspections is! List || inspections.isEmpty) return 'Not Inspected';
    DateTime? latest;
    for (final row in inspections) {
      final item = _map(row);
      final date = DateTime.tryParse(
        (item['inspected_at'] ?? item['last_inspection_date'])?.toString() ??
            '',
      );
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest == null ? 'Not Inspected' : _date(latest.toIso8601String());
  }

  Future<void> _openPlant(Map<String, dynamic> plant) async {
    await Navigator.push(
      context,
      plantDetailsRoute(
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
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
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
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
                gaplessPlayback: true,
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
        : label == 'Needs Attention'
        ? AppColors.warning
        : label == 'Dead'
        ? AppColors.danger
        : AppColors.textSecondary;
    final background = label == 'Healthy'
        ? AppColors.primaryContainer
        : label == 'Needs Attention'
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
