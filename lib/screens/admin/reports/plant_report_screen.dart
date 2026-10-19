import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../widgets/monitoring_outcomes_card.dart';
import '../../../models/inspection_schedule.dart';
import '../../../widgets/app_workspace_page.dart';
import '../../../theme/app_typography.dart';
import 'widgets/report_readable_widgets.dart';
import '../../../services/report_export_data.dart';
import '../../../services/report_export_service.dart';
import '../../../widgets/report_export_dialog.dart';
import '../../../utils/user_facing_error.dart';
import '../../../models/app_role.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/compact_filter_panel.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_shell.dart';

class CollegePlantReportScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const CollegePlantReportScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<CollegePlantReportScreen> createState() =>
      _CollegePlantReportScreenState();
}

class _CollegePlantReportScreenState extends State<CollegePlantReportScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final Map<int, DateTime> _inspectionDates = {};
  List<Map<String, dynamic>> _plants = [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  DateTimeRange? _dateRange;
  String _campus = 'All';
  String _college = 'All';
  String _plantType = 'All';
  String _healthStatus = 'All';
  String _growthStage = 'All';

  // Readable aliases for the shared analytics palette. The actual color
  // values remain centralized in AppColors.

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  String _related(Map<String, dynamic> plant, String relation, String field) =>
      _map(plant[relation])[field]?.toString() ?? 'Unknown';

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!RoleCapabilities.fromValue(widget.role).canViewReports) {
        throw Exception('Staff report access required.');
      }
      if (widget.role == 'campus_admin' && widget.campusId == null) {
        throw Exception('This Campus Admin account has no assigned campus.');
      }
      if ((widget.role == 'college_admin' ||
              widget.role == 'inspection_team') &&
          widget.collegeId == null) {
        throw Exception('This account has no assigned college.');
      }

      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _supabase
          .from('plant')
          .select('''
        plant_id, variety, date_planted, tree_planter, created_at,
        campus_id, college_id, last_inspected_on, next_inspection_due_on, inspection_interval_days,
        plant_classification (common_name, scientific_name, plant_type),
        campus:campus!plant_campus_id_fkey (campus_name), college (college_name),
        growth_status (growth_stage), health_status (status_name),
        qr_tag:qr_tag!plant_qr_tag_id_fkey(qr_code_string),
        town(town_name), barangay(barangay_name)
      ''')
          .isFilter('archived_at', null);
      if (widget.role == 'campus_admin') {
        query = query.eq('campus_id', widget.campusId!);
      } else if (widget.role == 'college_admin' ||
          widget.role == 'inspection_team') {
        if (widget.campusId == null) {
          throw Exception('This account has no assigned campus.');
        }
        query = query
            .eq('campus_id', widget.campusId!)
            .eq('college_id', widget.collegeId!);
      }
      final plants = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final page = List<Map<String, dynamic>>.from(
          await query
              .order('created_at', ascending: false)
              .order('plant_id')
              .range(offset, offset + 499),
        );
        plants.addAll(page);
        if (page.length < 500) break;
      }

      final inspections = <int, DateTime>{};
      for (final plant in plants) {
        final last = DateTime.tryParse(
          plant['last_inspected_on']?.toString() ?? '',
        );
        if (last != null) inspections[plant['plant_id'] as int] = last;
      }
      final ids = plants.map((plant) => plant['plant_id'] as int).toList();
      if (ids.isNotEmpty) {
        try {
          final history = await _supabase
              .from('inspection')
              .select('plant_id, inspected_at, last_inspection_date')
              .inFilter('plant_id', ids)
              .order('inspected_at', ascending: false);
          for (final item in history) {
            final id = item['plant_id'] as int;
            final date = DateTime.tryParse(
              (item['inspected_at'] ?? item['last_inspection_date'])
                      ?.toString() ??
                  '',
            );
            if (date != null) inspections.putIfAbsent(id, () => date);
          }
        } catch (_) {
          // Inspection metrics safely fall back to zero.
        }
      }

      final normalizedCampus = _normalizeFilterValue(
        _campus,
        plants.map((plant) => _related(plant, 'campus', 'campus_name')),
      );
      final collegeSource = normalizedCampus == 'All'
          ? plants
          : plants.where(
              (plant) =>
                  _related(plant, 'campus', 'campus_name') == normalizedCampus,
            );
      final normalizedCollege = _normalizeFilterValue(
        _college,
        collegeSource.map(
          (plant) => _related(plant, 'college', 'college_name'),
        ),
      );
      final normalizedPlantType = _normalizeFilterValue(
        _plantType,
        plants.map(
          (plant) => _related(plant, 'plant_classification', 'plant_type'),
        ),
      );
      final normalizedGrowthStage = _normalizeFilterValue(
        _growthStage,
        plants.map((plant) => _related(plant, 'growth_status', 'growth_stage')),
      );

      if (!mounted) return;
      setState(() {
        _plants = plants;
        _campus = normalizedCampus;
        _college = normalizedCollege;
        _plantType = normalizedPlantType;
        _growthStage = normalizedGrowthStage;
        _inspectionDates
          ..clear()
          ..addAll(inspections);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _health(Map<String, dynamic> plant) {
    final value = _related(plant, 'health_status', 'status_name').toLowerCase();
    if (value == 'alive' || value == 'healthy') return 'Healthy';
    if (value == 'dying' || value == 'at risk') return 'Needs Attention';
    if (value == 'dead') return 'Dead';
    return 'Unknown';
  }

  DateTime? _createdAt(Map<String, dynamic> plant) =>
      DateTime.tryParse(plant['created_at']?.toString() ?? '');

  String _normalizeFilterValue(String current, Iterable<String> values) {
    if (current == 'All') return current;
    final available = values.where((value) => value != 'Unknown').toSet();
    return available.contains(current) ? current : 'All';
  }

  List<String> _options(String Function(Map<String, dynamic>) getter) {
    final values =
        _plants
            .map(getter)
            .where((value) => value != 'Unknown')
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<Map<String, dynamic>> get _filteredPlants {
    final term = _searchController.text.trim().toLowerCase();
    return _plants.where((plant) {
      final campus = _related(plant, 'campus', 'campus_name');
      final college = _related(plant, 'college', 'college_name');
      final type = _related(plant, 'plant_classification', 'plant_type');
      final growth = _related(plant, 'growth_status', 'growth_stage');
      final created = _createdAt(plant);
      final searchable = [
        plant['plant_id'],
        _tag(plant),
        _related(plant, 'plant_classification', 'common_name'),
        _related(plant, 'plant_classification', 'scientific_name'),
        type,
        campus,
        college,
        plant['variety'],
      ].join(' ').toLowerCase();
      return (_dateRange == null ||
              (created != null &&
                  !created.isBefore(_dateRange!.start) &&
                  created.isBefore(
                    _dateRange!.end.add(const Duration(days: 1)),
                  ))) &&
          (_campus == 'All' || campus == _campus) &&
          (_college == 'All' || college == _college) &&
          (_plantType == 'All' || type == _plantType) &&
          (_healthStatus == 'All' || _health(plant) == _healthStatus) &&
          (_growthStage == 'All' || growth == _growthStage) &&
          (term.isEmpty || searchable.contains(term));
    }).toList();
  }

  int _count(String status) =>
      _filteredPlants.where((plant) => _health(plant) == status).length;

  bool get _hasActiveFilters =>
      _dateRange != null ||
      _campus != 'All' ||
      _college != 'All' ||
      _plantType != 'All' ||
      _healthStatus != 'All' ||
      _growthStage != 'All' ||
      _searchController.text.trim().isNotEmpty;

  int get _activeFilterCount => [
    _dateRange != null,
    _campus != 'All',
    _college != 'All',
    _plantType != 'All',
    _healthStatus != 'All',
    _growthStage != 'All',
    _searchController.text.trim().isNotEmpty,
  ].where((active) => active).length;

  int get _advancedFilterCount => [
    _dateRange != null,
    _campus != 'All',
    _college != 'All',
    _plantType != 'All',
    _healthStatus != 'All',
    _growthStage != 'All',
  ].where((active) => active).length;

  bool _inspected(Map<String, dynamic> plant) =>
      _inspectionDates.containsKey(plant['plant_id'] as int);
  bool _overdue(Map<String, dynamic> plant) {
    return InspectionSchedule.isOverdue(
      plant,
      lastInspected: _inspectionDates[plant['plant_id'] as int],
    );
  }

  Future<void> _openReportExport() async {
    if (_exporting || _loading || _error != null) return;
    final choice = await showDialog<ReportExportChoice>(
      context: context,
      builder: (_) => const ReportExportDialog(),
    );
    if (choice == null || !mounted) return;
    setState(() => _exporting = true);
    final service = ReportExportService();
    try {
      final plants = _filteredPlants
          .map(
            (p) => <String, dynamic>{
              ...p,
              'last_inspected_on':
                  p['last_inspected_on'] ??
                  _inspectionDates[p['plant_id']]?.toIso8601String(),
            },
          )
          .toList();
      final filters = [
        'Campus: $_campus',
        'College: $_college',
        'Type: $_plantType',
        'Health: $_healthStatus',
        'Growth: $_growthStage',
        if (_searchController.text.trim().isNotEmpty)
          'Search: ${_searchController.text.trim()}',
        'Registration dates: ${_dateRange == null ? "All" : "${ReportExportData.date(_dateRange!.start)} to ${ReportExportData.date(_dateRange!.end)}"}',
      ].join('; ');
      if (choice.kind != ReportKind.outcomes) {
        await service.validatePlants(
          plants.map((p) => p['plant_id'] as int).toList(),
        );
      }
      final history = choice.kind == ReportKind.history
          ? await service.history(
              plants.map((p) => p['plant_id'] as int).toList(),
              start: choice.period?.start,
              end: choice.period?.end,
            )
          : <Map<String, dynamic>>[];
      final outcomes = choice.kind == ReportKind.outcomes
          ? await service.outcomes()
          : null;
      if (!mounted) return;
      final generated = ReportExportData.manilaNow();
      final report = ReportExportData.build(
        kind: choice.kind,
        plants: plants,
        history: history,
        outcomes: outcomes,
        scope:
            '$_scopeLabel (Campus ID: ${widget.campusId ?? "All"}; College ID: ${widget.collegeId ?? "All"})',
        preparedBy: widget.username,
        filters: filters,
        generated: generated,
        inspectionPeriod: choice.period == null
            ? 'All inspection dates'
            : '${ReportExportData.date(choice.period!.start)} to ${ReportExportData.date(choice.period!.end)}',
      );
      final filename =
          'EcoTag_${choice.kind.name}_${ReportExportData.date(generated)}_${generated.hour.toString().padLeft(2, "0")}${generated.minute.toString().padLeft(2, "0")}';
      if (choice.format == ReportExportFormat.pdf) {
        final bytes = await service.pdfBytes(report);
        if (!mounted) return;
        await Printing.layoutPdf(
          name: '$filename.pdf',
          onLayout: (_) async => bytes,
        );
      } else {
        final saved = await service.saveCsv(report, filename);
        if (saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Spreadsheet saved or sent to your browser downloads.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback: 'Report export failed. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _tag(Map<String, dynamic> plant) {
    final tag = _map(plant['qr_tag'])['qr_code_string']?.toString();
    return tag == null || tag.isEmpty ? 'PLANT-${plant['plant_id']}' : tag;
  }

  bool get _universityScope =>
      widget.role == 'university_admin' || widget.role == 'super_admin';
  String get _scopeLabel =>
      widget.role == 'college_admin' || widget.role == 'inspection_team'
      ? 'Assigned College'
      : widget.role == 'campus_admin'
      ? 'Assigned Campus'
      : 'All Campuses';

  @override
  Widget build(BuildContext context) {
    final desktop = AppBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);
    return AppShell(
      activeRoute: '/reports',
      mobileTitle: 'Reports',
      mobileSubtitle: _scopeLabel,
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      campusId: widget.campusId,
      collegeId: widget.collegeId,
      userName: widget.username,
      child: AppWorkspacePage(
        header: desktop
            ? AppPageHeader(
                title: 'Reports & Analytics',
                subtitle:
                    '$_scopeLabel · plant health, growth, and inspections',
                trailing: FilledButton.icon(
                  onPressed: _loading || _exporting || _error != null
                      ? null
                      : _openReportExport,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _exporting ? 'Preparing Report...' : 'Export Report',
                  ),
                ),
              )
            : Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading || _exporting || _error != null
                      ? null
                      : _openReportExport,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _exporting ? 'Preparing Report...' : 'Export Report',
                  ),
                ),
              ),
        tools: !_loading && _error == null ? _filterCard() : null,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : _error != null
            ? SingleChildScrollView(child: _errorCard())
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _kpiCards(),
                    const SizedBox(height: AppSpacing.lg),
                    const MonitoringOutcomesCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _analytics(),
                    const SizedBox(height: AppSpacing.lg),
                    _inspectionAndScope(),
                    const SizedBox(height: AppSpacing.lg),
                    _detailedReport(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filterCard() => AppToolbarCard(
    child: LayoutBuilder(
      builder: (_, constraints) => AppBreakpoints.isPhone(constraints.maxWidth)
          ? _mobileReportFilters()
          : _desktopReportFilters(constraints.maxWidth),
    ),
  );

  Widget _desktopReportFilters(double maxWidth) => CompactFilterPanel(
    search: _reportSearchField(),
    controls: [
      OutlinedButton.icon(
        onPressed: _showReportFilterSheet,
        icon: const Icon(Icons.tune_rounded, size: 19),
        label: Text(
          _advancedFilterCount == 0
              ? 'Filters'
              : 'Filters ($_advancedFilterCount)',
        ),
      ),
      if (_hasActiveFilters)
        TextButton(onPressed: _resetFilters, child: const Text('Reset')),
    ],
    choices: [
      for (final status in _reportHealthOptions)
        _reportHealthChoice(
          status,
          _healthStatus,
          (value) => setState(() => _healthStatus = value),
        ),
      if (_hasActiveFilters) _reportActiveBadge(_activeFilterCount),
    ],
    resultSummary: [
      '${_filteredPlants.length} of ${_plants.length} plants match',
      if (_dateRange != null)
        '${_shortDate(_dateRange!.start)} – ${_shortDate(_dateRange!.end)}',
      if (_campus != 'All') _campus,
      if (_college != 'All') _college,
      if (_plantType != 'All') _plantType,
      if (_growthStage != 'All') _growthStage,
    ].join(' · '),
  );

  Widget _mobileReportFilters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _reportSearchField()),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _showReportFilterSheet,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: BorderSide(
                  color: _advancedFilterCount > 0
                      ? AppColors.green
                      : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  if (_advancedFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    _reportCountBadge(_advancedFilterCount),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      if (_advancedFilterCount > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadii.medium,
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_rounded,
                size: 16,
                color: AppColors.green,
              ),
              const SizedBox(width: 6),
              Text(
                '$_advancedFilterCount ${_advancedFilterCount == 1 ? 'filter' : 'filters'} applied',
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _resetAdvancedFilters,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 17),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 10),
      _reportResultSummary(),
    ],
  );

  Widget _reportResultSummary() => Row(
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
          '${_filteredPlants.length} of ${_plants.length} plants match',
          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      if (_hasActiveFilters)
        TextButton(
          onPressed: _resetFilters,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Clear All'),
        ),
    ],
  );

  Widget _reportSearchField() => TextField(
    controller: _searchController,
    onChanged: (_) => setState(() {}),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search plant, QR, campus, college, or variety…',
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
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
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

  List<String> _collegeOptionsFor(String campus) {
    final source = campus == 'All'
        ? _plants
        : _plants.where(
            (plant) => _related(plant, 'campus', 'campus_name') == campus,
          );
    final values =
        source
            .map((plant) => _related(plant, 'college', 'college_name'))
            .where((value) => value != 'Unknown')
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey(Object.hashAll([label, value, ...options])),
    initialValue: options.contains(value) ? value : 'All',
    isExpanded: true,
    decoration: _inputDecoration(label, null),
    items: options
        .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
        .toList(),
    onChanged: (item) => item == null ? null : onChanged(item),
  );

  static const _reportHealthOptions = [
    'All',
    'Healthy',
    'Needs Attention',
    'Dead',
    'Unknown',
  ];

  Color _reportHealthColor(String value) => value == 'Needs Attention'
      ? AppColors.warningAccent
      : value == 'Dead'
      ? AppColors.danger
      : value == 'Unknown'
      ? AppColors.textSecondary
      : AppColors.green;

  IconData _reportHealthIcon(String value) => value == 'All'
      ? Icons.apps_rounded
      : value == 'Healthy'
      ? Icons.eco_rounded
      : value == 'Needs Attention'
      ? Icons.warning_amber_rounded
      : value == 'Dead'
      ? Icons.local_florist_outlined
      : Icons.help_outline_rounded;

  Widget _reportHealthChoice(
    String value,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final active = value == selected;
    final accent = _reportHealthColor(value);
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        _reportHealthIcon(value),
        size: 17,
        color: active ? accent : AppColors.textSecondary,
      ),
      label: Text(value),
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

  Widget _reportActiveBadge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.warningContainer,
      borderRadius: AppRadii.fullyRounded,
      border: Border.all(color: AppColors.warningAccent),
    ),
    child: Text(
      '$count active',
      style: const TextStyle(
        fontSize: AppTypography.caption,
        fontWeight: FontWeight.w800,
        color: AppColors.warning,
      ),
    ),
  );

  Widget _reportCountBadge(int count) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: const BoxDecoration(
      color: AppColors.warningAccent,
      shape: BoxShape.circle,
    ),
    child: Text(
      count.toString(),
      style: const TextStyle(
        fontSize: AppTypography.caption,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );

  Widget _stagedDateField(
    BuildContext context,
    DateTimeRange? value,
    ValueChanged<DateTimeRange> onChanged,
  ) => InkWell(
    onTap: () async {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: value,
      );
      if (selected != null) onChanged(selected);
    },
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: _inputDecoration(
        'Registration date',
        Icons.date_range_outlined,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null
                  ? 'All Dates'
                  : '${_shortDate(value.start)} – ${_shortDate(value.end)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value != null)
            const Icon(Icons.check_circle, size: 18, color: AppColors.green),
        ],
      ),
    ),
  );

  Future<void> _showReportFilterSheet() async {
    var pendingDate = _dateRange;
    var pendingCampus = _campus;
    var pendingCollege = _college;
    var pendingPlantType = _plantType;
    var pendingHealth = _healthStatus;
    var pendingGrowth = _growthStage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => FractionallySizedBox(
          heightFactor: .92,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                          borderRadius: BorderRadius.circular(11),
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
                              'Filter Report',
                              style: TextStyle(
                                fontSize: AppTypography.sectionTitle,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Refine The Records Shown In Analytics',
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Filters',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATE & LOCATION',
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _stagedDateField(
                          sheetContext,
                          pendingDate,
                          (value) => updateSheet(() => pendingDate = value),
                        ),
                        if (_universityScope) ...[
                          const SizedBox(height: 10),
                          _dropdown(
                            'Campus',
                            pendingCampus,
                            _options(
                              (plant) =>
                                  _related(plant, 'campus', 'campus_name'),
                            ),
                            (value) => updateSheet(() {
                              pendingCampus = value;
                              pendingCollege = 'All';
                            }),
                          ),
                        ],
                        if (widget.role != 'college_admin') ...[
                          const SizedBox(height: 10),
                          _dropdown(
                            'College',
                            pendingCollege,
                            _collegeOptionsFor(pendingCampus),
                            (value) =>
                                updateSheet(() => pendingCollege = value),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'PLANT DETAILS',
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _dropdown(
                          'Plant Type',
                          pendingPlantType,
                          _options(
                            (plant) => _related(
                              plant,
                              'plant_classification',
                              'plant_type',
                            ),
                          ),
                          (value) =>
                              updateSheet(() => pendingPlantType = value),
                        ),
                        const SizedBox(height: 10),
                        _dropdown(
                          'Growth Stage',
                          pendingGrowth,
                          _options(
                            (plant) => _related(
                              plant,
                              'growth_status',
                              'growth_stage',
                            ),
                          ),
                          (value) => updateSheet(() => pendingGrowth = value),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'HEALTH STATUS',
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _reportHealthOptions
                              .map(
                                (value) => _reportHealthChoice(
                                  value,
                                  pendingHealth,
                                  (selected) => updateSheet(
                                    () => pendingHealth = selected,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => updateSheet(() {
                            pendingDate = null;
                            pendingCampus = 'All';
                            pendingCollege = 'All';
                            pendingPlantType = 'All';
                            pendingHealth = 'All';
                            pendingGrowth = 'All';
                          }),
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
                            setState(() {
                              _dateRange = pendingDate;
                              _campus = pendingCampus;
                              _college = pendingCollege;
                              _plantType = pendingPlantType;
                              _healthStatus = pendingHealth;
                              _growthStage = pendingGrowth;
                            });
                            Navigator.pop(sheetContext);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.green,
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
      );

  void _resetAdvancedFilters() => setState(() {
    _dateRange = null;
    _campus = 'All';
    _college = 'All';
    _plantType = 'All';
    _healthStatus = 'All';
    _growthStage = 'All';
  });

  void _resetFilters() => setState(() {
    _dateRange = null;
    _campus = 'All';
    _college = 'All';
    _plantType = 'All';
    _healthStatus = 'All';
    _growthStage = 'All';
    _searchController.clear();
  });

  Widget _kpiCards() => LayoutBuilder(
    builder: (_, constraints) {
      final columns = AppBreakpoints.isDesktop(constraints.maxWidth)
          ? 3
          : AppBreakpoints.isTablet(constraints.maxWidth)
          ? 2
          : constraints.maxWidth >= 360
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;
      final inspected = _filteredPlants.where(_inspected).length;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _kpi(
            'Total Plants',
            _filteredPlants.length,
            Icons.park_rounded,
            AppColors.green,
            width,
          ),
          _kpi(
            'Healthy',
            _count('Healthy'),
            Icons.eco_rounded,
            AppColors.green,
            width,
          ),
          _kpi(
            'Needs Attention',
            _count('Needs Attention'),
            Icons.warning_amber_rounded,
            AppColors.warningAccent,
            width,
          ),
          _kpi(
            'Dead',
            _count('Dead'),
            Icons.local_florist_outlined,
            AppColors.danger,
            width,
          ),
          _kpi(
            'Inspected',
            inspected,
            Icons.fact_check_outlined,
            AppColors.info,
            width,
          ),
          _kpi(
            'Pending',
            _filteredPlants.length - inspected,
            Icons.pending_actions_outlined,
            AppColors.warningAccent,
            width,
          ),
        ],
      );
    },
  );

  Widget _kpi(
    String title,
    int value,
    IconData icon,
    Color color,
    double width,
  ) => SizedBox(
    width: width,
    child: AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: AppTypography.metric,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                Text(
                  title,
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
        ],
      ),
    ),
  );

  Widget _analytics() => LayoutBuilder(
    builder: (_, constraints) {
      final width = !AppBreakpoints.isPhone(constraints.maxWidth)
          ? (constraints.maxWidth - AppSpacing.lg) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          SizedBox(width: width, child: _healthChart()),
          SizedBox(width: width, child: _growthChart()),
          SizedBox(width: width, child: _trendChart()),
          SizedBox(width: width, child: _scopeChart()),
        ],
      );
    },
  );

  Widget _chartCard(
    String title,
    String subtitle,
    Widget chart, {
    bool naturalHeight = false,
  }) => AppCard(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppTypography.sectionTitle,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (naturalHeight)
          chart
        else
          SizedBox(
            height:
                220 +
                32 *
                    (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2),
            child: chart,
          ),
      ],
    ),
  );

  Widget _healthChart() {
    final values = [
      ('Healthy', _count('Healthy'), AppColors.green),
      ('Needs Attention', _count('Needs Attention'), AppColors.warningAccent),
      ('Dead', _count('Dead'), AppColors.danger),
      ('Unknown', _count('Unknown'), AppColors.textSecondary),
    ];
    final total = values.fold<int>(0, (sum, item) => sum + item.$2);
    return _chartCard(
      'Plant Health',
      'Current health status distribution',
      total == 0 ? _emptyChart() : ReportHealthDistribution(values: values),
      naturalHeight: total > 0,
    );
  }

  Map<String, int> _groupCounts(
    Iterable<Map<String, dynamic>> plants,
    String Function(Map<String, dynamic>) keyOf,
  ) {
    final result = <String, int>{};
    for (final plant in plants) {
      final key = keyOf(plant);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  Widget _growthChart() {
    final counts = _groupCounts(
      _filteredPlants,
      (plant) => _related(plant, 'growth_status', 'growth_stage'),
    );
    return _chartCard(
      'Growth Stage',
      'Plants By Development Stage',
      counts.isEmpty ? _emptyChart() : _barChart(counts, AppColors.green),
    );
  }

  Widget _scopeChart() {
    final relation = _universityScope ? 'campus' : 'college';
    final field = _universityScope ? 'campus_name' : 'college_name';
    final counts = _groupCounts(
      _filteredPlants,
      (plant) => _related(plant, relation, field),
    );
    return _chartCard(
      _universityScope ? 'Campus Distribution' : 'College Distribution',
      _universityScope
          ? 'Registered plants per campus'
          : 'Registered plants per college',
      counts.isEmpty ? _emptyChart() : _barChart(counts, AppColors.info),
    );
  }

  Widget _barChart(Map<String, int> counts, Color color) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = entries.take(6).toList();
    final maximum = shown.fold<int>(
      1,
      (value, item) => math.max(value, item.value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
        final chartWidth = math.max(
          constraints.maxWidth,
          shown.length * 72.0 * scale,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: BarChart(
              BarChartData(
                maxY: maximum * 1.25,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize:
                          48 *
                          MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= shown.length) {
                          return const SizedBox();
                        }
                        final label = shown[index].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: chartWidth / shown.length - 12,
                            child: Tooltip(
                              message: label,
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTypography.caption,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: shown.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: color,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _trendChart() {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index), 1),
    );
    final values = months.map((month) {
      return _filteredPlants.where((plant) {
        final created = _createdAt(plant);
        return created != null &&
            created.year == month.year &&
            created.month == month.month;
      }).length;
    }).toList();
    final maximum = values.fold<int>(1, math.max);
    const names = [
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
    return _chartCard(
      'Registration Trend',
      'Plants registered during the last six months',
      LineChart(
        LineChartData(
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: maximum * 1.25,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize:
                    32 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    names[months[value.toInt().clamp(0, 5)].month - 1],
                    style: const TextStyle(fontSize: AppTypography.caption),
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: values
                  .asMap()
                  .entries
                  .map(
                    (item) =>
                        FlSpot(item.key.toDouble(), item.value.toDouble()),
                  )
                  .toList(),
              color: AppColors.green,
              barWidth: 3,
              isCurved: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.green.withValues(alpha: .12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart() => const Center(
    child: Text(
      'No Data For The Selected Filters',
      style: TextStyle(color: AppColors.textSecondary),
    ),
  );

  Widget _inspectionAndScope() => LayoutBuilder(
    builder: (_, constraints) {
      final width = !AppBreakpoints.isPhone(constraints.maxWidth)
          ? (constraints.maxWidth - AppSpacing.lg) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          SizedBox(width: width, child: _inspectionOverview()),
          SizedBox(width: width, child: _scopeSummary()),
        ],
      );
    },
  );

  Widget _inspectionOverview() {
    final inspected = _filteredPlants.where(_inspected).length;
    final pending = _filteredPlants.length - inspected;
    final overdue = _filteredPlants.where(_overdue).length;
    final completion = _filteredPlants.isEmpty
        ? 0.0
        : inspected / _filteredPlants.length;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inspection Overview',
            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 18),
          _metricRow('Inspected', inspected, AppColors.info),
          _metricRow('Pending Inspection', pending, AppColors.warningAccent),
          _metricRow('Overdue Inspections', overdue, AppColors.danger),
          const SizedBox(height: 15),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Completion',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(completion * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completion,
            minHeight: 9,
            borderRadius: BorderRadius.circular(10),
            color: AppColors.green,
            backgroundColor: AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, int value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _scopeSummary() {
    final relation = _universityScope ? 'campus' : 'college';
    final field = _universityScope ? 'campus_name' : 'college_name';
    final entries = _groupCounts(
      _filteredPlants,
      (plant) => _related(plant, relation, field),
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _universityScope ? 'Campus Summary' : 'College Summary',
            style: const TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            SizedBox(height: 116, child: _emptyChart())
          else
            ...entries
                .take(5)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _detailedReport() {
    final plants = _filteredPlants;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Plant Report',
            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          Text(
            '${plants.length} matching records',
            style: const TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          if (plants.isEmpty)
            SizedBox(height: 180, child: _emptyChart())
          else
            LayoutBuilder(
              builder: (_, constraints) {
                if (AppBreakpoints.isPhone(constraints.maxWidth)) {
                  return _mobileDetailedReport(plants);
                }
                return SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(
                        AppColors.background,
                      ),
                      columnSpacing: 25,
                      columns: const [
                        DataColumn(label: Text('QR ID')),
                        DataColumn(label: Text('PLANT')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('CAMPUS')),
                        DataColumn(label: Text('COLLEGE')),
                        DataColumn(label: Text('STAGE')),
                        DataColumn(label: Text('HEALTH')),
                        DataColumn(label: Text('REGISTERED')),
                        DataColumn(label: Text('LAST INSPECTION')),
                      ],
                      rows: plants.map((plant) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_tag(plant))),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _related(
                                        plant,
                                        'plant_classification',
                                        'common_name',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _related(
                                        plant,
                                        'plant_classification',
                                        'scientific_name',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: AppTypography.caption,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _related(
                                  plant,
                                  'plant_classification',
                                  'plant_type',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(_related(plant, 'campus', 'campus_name')),
                            ),
                            DataCell(
                              Text(_related(plant, 'college', 'college_name')),
                            ),
                            DataCell(
                              Text(
                                _related(
                                  plant,
                                  'growth_status',
                                  'growth_stage',
                                ),
                              ),
                            ),
                            DataCell(_healthChip(_health(plant))),
                            DataCell(
                              Text(
                                _formatDate(
                                  _createdAt(plant),
                                  empty: 'Unknown',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatDate(
                                  _inspectionDates[plant['plant_id'] as int],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _mobileDetailedReport(List<Map<String, dynamic>> plants) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: plants
            .map(
              (plant) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _mobileReportCard(plant),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _mobileReportCard(Map<String, dynamic> plant) {
    final name = _related(plant, 'plant_classification', 'common_name');
    final scientificName = _related(
      plant,
      'plant_classification',
      'scientific_name',
    );
    final plantId = plant['plant_id'] as int;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.green,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      scientificName,
                      style: const TextStyle(
                        fontSize: AppTypography.caption,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _healthChip(_health(plant)),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              _tag(plant),
              style: const TextStyle(
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (_, constraints) {
              final itemWidth =
                  constraints.maxWidth >= 280 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.4
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _mobileReportDetail(
                    'Type',
                    _related(plant, 'plant_classification', 'plant_type'),
                    itemWidth,
                  ),
                  _mobileReportDetail(
                    'Growth Stage',
                    _related(plant, 'growth_status', 'growth_stage'),
                    itemWidth,
                  ),
                  _mobileReportDetail(
                    'Campus',
                    _related(plant, 'campus', 'campus_name'),
                    itemWidth,
                  ),
                  _mobileReportDetail(
                    'College',
                    _related(plant, 'college', 'college_name'),
                    itemWidth,
                  ),
                  _mobileReportDetail(
                    'Registered',
                    _formatDate(_createdAt(plant), empty: 'Unknown'),
                    itemWidth,
                  ),
                  _mobileReportDetail(
                    'Last Inspection',
                    _formatDate(_inspectionDates[plantId]),
                    itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mobileReportDetail(String label, String value, double width) =>
      ReportDetailField(label: label, value: value, width: width);

  Widget _healthChip(String value) {
    final color = value == 'Healthy'
        ? AppColors.green
        : value == 'Needs Attention'
        ? AppColors.warningAccent
        : value == 'Dead'
        ? AppColors.danger
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _errorCard() => AppCard(
    child: SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    ),
  );

  String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _formatDate(DateTime? date, {String empty = 'Not Inspected'}) {
    if (date == null) return empty;
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
