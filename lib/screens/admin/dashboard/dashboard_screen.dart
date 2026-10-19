import 'package:flutter/material.dart';
import '../../../widgets/inspection_reminders.dart';
import '../../inspections/inspection_outbox_screen.dart';
import '../../../theme/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../../models/plant_record_lock.dart';
import '../../../theme/app_layout.dart';
import '../../../utils/user_facing_error.dart';
import '../../../widgets/app_error_state.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/inspection_overview_card.dart';
import '../../../widgets/equal_height_cards.dart';
import 'widgets/dashboard_stat_card.dart';
import 'widgets/dashboard_priority_layout.dart';
import 'widgets/dashboard_page_header.dart';
import 'widgets/campus_overview_card.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/recent_plants_table.dart';

import '../registration/register_plant_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;

  String? _errorMessage;

  int _totalPlants = 0;
  int _healthyCount = 0;
  int _dyingCount = 0;
  int _deadCount = 0;
  int _overdueCount = 0;
  int _dueTodayCount = 0;
  int _unscheduledCount = 0;
  DateTime? _lastInspection;

  List<Map<String, dynamic>> _recentPlants = [];
  Map<String, int> _campusPlantCounts = {};

  String _currentUsername = '';
  String _currentRole = '';

  int? _currentCampusId;
  int? _currentCollegeId;

  // ============================================================
  // USER INFORMATION
  // ============================================================

  String get _userName {
    if (_currentUsername.isNotEmpty) {
      return _currentUsername;
    }

    return widget.username;
  }

  String get _userRole {
    final role = _currentRole.isNotEmpty ? _currentRole : widget.role;

    switch (role) {
      case 'super_admin':
        return 'Super Admin';

      case 'university_admin':
        return 'University Admin';

      case 'campus_admin':
        return 'Campus Admin';

      case 'college_admin':
        return 'College Admin';

      case 'inspection_team':
        return 'Inspection Team';

      case 'guest':
        return 'Guest';

      default:
        return role;
    }
  }

  String get _role {
    return _currentRole.isNotEmpty ? _currentRole : widget.role;
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  bool get _canRegisterPlant {
    return _role == 'college_admin' || _role == 'inspection_team';
  }

  bool get _canViewPlantList {
    return _role == 'super_admin' ||
        _role == 'university_admin' ||
        _role == 'campus_admin' ||
        _role == 'college_admin' ||
        _role == 'inspection_team';
  }

  bool get _canGenerateReport {
    return _role == 'super_admin' ||
        _role == 'university_admin' ||
        _role == 'campus_admin' ||
        _role == 'college_admin';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _currentUsername = widget.username;

    _currentRole = widget.role;

    _currentCampusId = widget.campusId;

    _currentCollegeId = widget.collegeId;

    _loadDashboardData();
  }

  // ============================================================
  // LOAD CURRENT USER FROM USERS TABLE
  // ============================================================

  Future<void> _loadCurrentUser() async {
    final user = await _supabase
        .from('users')
        .select('''
          user_id,
          username,
          role,
          campus_id,
          college_id
        ''')
        .eq('user_id', widget.userId)
        .maybeSingle();

    if (user == null) {
      throw Exception('Logged-in EcoTag user was not found.');
    }

    final role = user['role']?.toString().toLowerCase() ?? '';

    if (role.isEmpty) {
      throw Exception('This account has no assigned role.');
    }

    _currentUsername = user['username']?.toString() ?? widget.username;

    _currentRole = role;

    _currentCampusId = user['campus_id'];

    _currentCollegeId = user['college_id'];
  }

  // ============================================================
  // VALIDATE ACCOUNT
  // ============================================================

  void _validateAccountScope() {
    if (_role == 'campus_admin' && _currentCampusId == null) {
      throw Exception('Campus Admin account has no assigned campus.');
    }

    if (_role == 'college_admin' && _currentCampusId == null) {
      throw Exception('College Admin account has no assigned campus.');
    }

    if (_role == 'inspection_team' &&
        (_currentCampusId == null || _currentCollegeId == null)) {
      throw Exception(
        'Inspection Team account has no assigned campus or college.',
      );
    }

    if (_role == 'college_admin' && _currentCollegeId == null) {
      throw Exception('College Admin account has no assigned college.');
    }
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadCurrentUser();

      _validateAccountScope();

      // ========================================================
      // HEALTH QUERY
      // ========================================================

      var healthQuery = _supabase
          .from('plant')
          .select('''
        plant_id,
        campus_id,
        college_id,
        next_inspection_due_on, last_inspected_on,

        campus:campus!plant_campus_id_fkey (
          campus_name
        ),

        health_status (
          status_name
        )
      ''')
          .isFilter('archived_at', null);

      if (_role == 'campus_admin') {
        healthQuery = healthQuery.eq('campus_id', _currentCampusId!);
      }

      if (_role == 'college_admin' || _role == 'inspection_team') {
        healthQuery = healthQuery.eq('college_id', _currentCollegeId!);
      }

      final healthRows = await healthQuery;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int overdue = 0, dueToday = 0, unscheduled = 0;
      DateTime? lastInspection;
      for (final row in healthRows) {
        final inspected = DateTime.tryParse(
          row['last_inspected_on']?.toString() ?? '',
        );
        if (inspected != null &&
            (lastInspection == null || inspected.isAfter(lastInspection))) {
          lastInspection = inspected;
        }
        if (PlantRecordLock.isDead(row)) continue;
        final due = DateTime.tryParse(
          row['next_inspection_due_on']?.toString() ?? '',
        );
        if (due == null) {
          unscheduled++;
        } else if (due.isBefore(today)) {
          overdue++;
        } else if (due.year == today.year &&
            due.month == today.month &&
            due.day == today.day) {
          dueToday++;
        }
      }

      int healthy = 0;
      int dying = 0;
      int dead = 0;
      final campusCounts = <String, int>{};

      for (final row in healthRows) {
        final campus = row['campus'];
        final campusName = campus is Map
            ? campus['campus_name']?.toString()
            : null;
        if (campusName != null && campusName.isNotEmpty) {
          campusCounts[campusName] = (campusCounts[campusName] ?? 0) + 1;
        }
        final healthStatus = row['health_status'];

        if (healthStatus == null) {
          continue;
        }

        final status = healthStatus['status_name']?.toString().toLowerCase();

        if (status == 'alive' || status == 'healthy') {
          healthy++;
        } else if (status == 'dying' || status == 'at risk') {
          dying++;
        } else if (status == 'dead') {
          dead++;
        }
      }

      // ========================================================
      // RECENT PLANTS
      // ========================================================

      var recentQuery = _supabase
          .from('plant')
          .select('''
        plant_id,
        campus_id,
        college_id,
        variety,
        date_planted,
        created_at,

        plant_classification (
          common_name,
          plant_type
        ),

        campus:campus!plant_campus_id_fkey (
          campus_name
        ),

        growth_status (
          growth_stage
        ),

        health_status (
          status_name
        )
      ''')
          .isFilter('archived_at', null);

      if (_role == 'campus_admin') {
        recentQuery = recentQuery.eq('campus_id', _currentCampusId!);
      }

      if (_role == 'college_admin' || _role == 'inspection_team') {
        recentQuery = recentQuery.eq('college_id', _currentCollegeId!);
      }

      final recentRows = await recentQuery
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      setState(() {
        _totalPlants = healthRows.length;
        _overdueCount = overdue;
        _dueTodayCount = dueToday;
        _unscheduledCount = unscheduled;
        _lastInspection = lastInspection;

        _healthyCount = healthy;

        _dyingCount = dying;

        _deadCount = dead;

        _campusPlantCounts = campusCounts;

        _recentPlants = List<Map<String, dynamic>>.from(recentRows);

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('DASHBOARD LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/dashboard',

      mobileTitle: 'Dashboard',

      mobileSubtitle: _dashboardSubtitle,

      // Logged-in user/session data used by AppShell,
      // AppSidebar, and AppMobileNavbar.
      userId: widget.userId,

      username: _userName,

      role: _role,

      campusId: _currentCampusId,

      collegeId: _currentCollegeId,

      userName: _userName,

      userRole: _userRole,

      showQrButton: true,

      onQrPressed: () async {
        await Navigator.pushNamed(
          context,
          '/qr-scanner',
          arguments: {
            'user_id': widget.userId,

            'username': _userName,

            'role': _role,

            'campus_id': _currentCampusId,

            'college_id': _currentCollegeId,
          },
        );
        if (mounted) _loadDashboardData();
      },

      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDesktop) ...[
              DashboardPageHeader(
                description: _dashboardDescription,
                userRole: _userRole,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            InspectionReminders(
              scopeKey:
                  '${widget.userId}_${_role}_${_currentCampusId}_$_currentCollegeId',
              onOpen: () => _openInspectionQueue('action'),
            ),
            if (_role == 'inspection_team')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          InspectionOutboxScreen(userId: widget.userId),
                    ),
                  ),
                  icon: const Icon(Icons.offline_pin_outlined),
                  label: const Text('Offline inspections and pending uploads'),
                ),
              ),
            _buildDashboardContent(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEXT
  // ============================================================

  String get _dashboardSubtitle {
    switch (_role) {
      case 'super_admin':
        return 'System-wide plant overview';

      case 'university_admin':
        return 'University-wide plant overview';

      case 'campus_admin':
        return 'Campus plant overview';

      case 'college_admin':
        return 'College plant overview';

      default:
        return 'Plant monitoring overview';
    }
  }

  String get _dashboardDescription {
    switch (_role) {
      case 'super_admin':
        return 'Overview of plants across the EcoTag system';

      case 'university_admin':
        return 'Overview of plants across all CSU campuses';

      case 'campus_admin':
        return 'Overview of plants in your assigned campus';

      case 'college_admin':
        return 'Overview of plants in your assigned college';

      default:
        return 'Plant management and environmental monitoring';
    }
  }

  String get _totalPlantSubtitle {
    switch (_role) {
      case 'super_admin':
      case 'university_admin':
        return 'Across all campuses';

      case 'campus_admin':
        return 'In assigned campus';

      case 'college_admin':
        return 'In assigned college';

      default:
        return 'Registered plants';
    }
  }

  // ============================================================
  // HEADER
  // ============================================================

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;

        final hasInspectionOverview =
            _role == 'college_admin' || _role == 'inspection_team';
        return DashboardSummaryLayout(
          stats: _buildResponsiveStats(contentWidth),
          overview: hasInspectionOverview
              ? DashboardPriorityLayout(
                  work: _buildMonitoringWork(
                    contentWidth >= 720 &&
                            _totalPlants > 1 &&
                            MediaQuery.textScalerOf(context).scale(1) < 1.6
                        ? (contentWidth - AppSpacing.lg) / 2
                        : contentWidth,
                  ),
                  recent: _totalPlants > 1 ? _buildHealthChartCard() : null,
                )
              : null,
          priority: hasInspectionOverview && _dyingCount > 0
              ? _buildPriorityTaskCard()
              : null,
          analytics: _buildResponsiveAnalytics(contentWidth),
          trailing: !hasInspectionOverview && _totalPlants > 1
              ? _buildHealthChartCard()
              : null,
        );
      },
    );
  }

  Widget _buildPriorityTaskCard() {
    final noun = _dyingCount == 1 ? 'plant needs' : 'plants need';
    return Semantics(
      button: true,
      label: '$_dyingCount $noun attention. Open filtered plant records.',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: _openNeedsAttention,
          borderRadius: AppRadii.large,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: AppRadii.medium,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_dyingCount $noun attention',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Review these records and arrange an inspection.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> get _navigationArguments => {
    'user_id': widget.userId,
    'username': _userName,
    'role': _role,
    'campus_id': _currentCampusId,
    'college_id': _currentCollegeId,
  };

  Future<void> _openInspectionQueue(String filter) async {
    await Navigator.pushNamed(
      context,
      '/inspections',
      arguments: {..._navigationArguments, 'queue_filter': filter},
    );
    if (mounted) _loadDashboardData();
  }

  Widget _buildMonitoringWork(double availableWidth) {
    final last = _lastInspection;
    final needsFirstInspection = _totalPlants > _deadCount && last == null;
    return InspectionOverviewCard(
      availableWidth: availableWidth,
      metrics: [
        InspectionOverviewMetric(
          label: 'Overdue',
          count: _overdueCount,
          icon: Icons.schedule,
          onPressed: () => _openInspectionQueue('overdue'),
        ),
        InspectionOverviewMetric(
          label: 'Due today',
          count: _dueTodayCount,
          icon: Icons.today,
          onPressed: () => _openInspectionQueue('due_today'),
        ),
        if (_unscheduledCount > 0)
          InspectionOverviewMetric(
            label: 'No schedule',
            count: _unscheduledCount,
            icon: Icons.event_busy_outlined,
            onPressed: _openPlantList,
          ),
      ],
      lastInspection: last == null
          ? 'No inspection recorded yet.'
          : 'Last inspection: ${MaterialLocalizations.of(context).formatFullDate(last)}',
      message: _totalPlants == 0
          ? 'Start your college’s plant record.'
          : _overdueCount > 0
          ? 'Review overdue plants and arrange an inspection with your team.'
          : _dueTodayCount > 0
          ? 'Your team has inspections due today.'
          : needsFirstInspection
          ? 'Open a plant to review its schedule and arrange the first inspection.'
          : _unscheduledCount > 0
          ? 'Set inspection dates for plants without a schedule.'
          : 'No inspections due. Scan a tag to review plant health.',
      actions: [
        if (_totalPlants > 0)
          OutlinedButton.icon(
            onPressed: _overdueCount + _dueTodayCount > 0
                ? () => _openInspectionQueue('action')
                : _openPlantList,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: Text(
              _overdueCount + _dueTodayCount > 0
                  ? 'Review inspections'
                  : needsFirstInspection || _unscheduledCount > 0
                  ? 'Schedule inspection'
                  : 'Review plants',
            ),
          ),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.pushNamed(
              context,
              '/qr-scanner',
              arguments: _navigationArguments,
            );
            if (mounted) _loadDashboardData();
          },
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: const Text('Scan QR'),
        ),
        if (_totalPlants <= 1)
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(
                context,
                '/register-plant',
                arguments: _navigationArguments,
              );
              if (mounted) _loadDashboardData();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              _totalPlants == 0
                  ? 'Register first plant'
                  : 'Register another plant',
            ),
          ),
      ],
    );
  }

  Widget _buildRecentPlantShortlist() => AppCard(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent plants',
                  style: TextStyle(
                    fontSize: AppTypography.sectionTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openPlantList,
                child: const Text('View all'),
              ),
            ],
          ),
        ),
        for (final plant in _recentPlants.take(3))
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.eco_outlined, size: 20, color: AppColors.green),
            ),
            title: Text(
              (plant['plant_classification'] as Map?)?['common_name']
                      ?.toString() ??
                  'Plant',
            ),
            subtitle: Text(
              'Plant #${plant['plant_id']} · ${_recentHealthLabel(plant)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/plant-details',
                arguments: {
                  ..._navigationArguments,
                  'plant_id': plant['plant_id'],
                },
              );
              if (mounted) _loadDashboardData();
            },
          ),
      ],
    ),
  );

  String _recentHealthLabel(Map<String, dynamic> plant) {
    final health = (plant['health_status'] as Map?)?['status_name']
        ?.toString()
        .toLowerCase();
    return switch (health) {
      'alive' || 'healthy' => 'Healthy',
      'dying' || 'at risk' => 'Needs attention',
      'dead' => 'Dead',
      _ => 'Health not recorded',
    };
  }

  void _openNeedsAttention() => _openFilteredPlants('Needs attention');

  Future<void> _openFilteredPlants(String filter) async {
    await Navigator.pushNamed(
      context,
      '/plant-list',
      arguments: {
        'user_id': widget.userId,
        'username': _userName,
        'role': _role,
        'campus_id': _currentCampusId,
        'college_id': _currentCollegeId,
        'health_filter': filter,
      },
    );
    if (mounted) _loadDashboardData();
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return AppErrorState(
      title: 'Unable to load dashboard',
      message: userFacingError(
        _errorMessage ?? '',
        fallback: 'Your dashboard could not be loaded. Please try again.',
      ),
      technicalDetails: _errorMessage,
      onRetry: _loadDashboardData,
      minHeight: 400,
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildResponsiveStats(double contentWidth) {
    const gap = AppSpacing.md;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;

    final columns = largeText && contentWidth < 400
        ? 1
        : AppBreakpoints.isDesktop(contentWidth)
        ? 4
        : contentWidth >= 250
        ? 2
        : 1;

    final cards = <Widget>[
      DashboardStatCard(
        title: 'Total Plants',
        compact: !AppBreakpoints.isDesktop(contentWidth),
        onTap: () => _openFilteredPlants('All'),

        value: '$_totalPlants',

        subtext: _totalPlantSubtitle,

        icon: Icons.park_rounded,

        iconBgColor: AppColors.primaryContainer,

        iconColor: AppColors.green,
      ),

      DashboardStatCard(
        title: 'Healthy Plants',
        compact: !AppBreakpoints.isDesktop(contentWidth),
        onTap: () => _openFilteredPlants('Healthy'),

        value: '$_healthyCount',

        subtext: _totalPlants == 0
            ? ''
            : '${_healthyPercent.toStringAsFixed(0)}% of total plants',

        icon: Icons.eco_rounded,

        iconBgColor: AppColors.primaryContainer,

        iconColor: AppColors.green,

        progress: _totalPlants == 0 ? 0 : _healthyPercent / 100,
      ),

      DashboardStatCard(
        title: 'Needs attention',
        compact: !AppBreakpoints.isDesktop(contentWidth),
        onTap: _openNeedsAttention,

        value: '$_dyingCount',

        subtext: 'Requires inspection',

        icon: Icons.warning_amber_rounded,

        iconBgColor: AppColors.warningContainer,

        iconColor: AppColors.warningAccent,
      ),

      DashboardStatCard(
        title: 'Dead Plants',
        compact: !AppBreakpoints.isDesktop(contentWidth),
        onTap: () => _openFilteredPlants('Dead'),

        value: '$_deadCount',

        subtext: _totalPlants == 0
            ? ''
            : '${_deadPercent.toStringAsFixed(0)}% of total plants',

        icon: Icons.cancel_outlined,

        iconBgColor: AppColors.dangerContainer,

        iconColor: AppColors.danger,
      ),
    ];

    if (columns > 1) {
      return EqualHeightCards(columns: columns, gap: gap, children: cards);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(height: gap),
          cards[index],
        ],
      ],
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  Widget _buildResponsiveAnalytics(double contentWidth) {
    final recentPlants =
        (_role == 'college_admin' || _role == 'inspection_team')
        ? (_recentPlants.isEmpty ? null : _buildRecentPlantShortlist())
        : _buildResponsiveRecentPlants(contentWidth);
    final actions = _role == 'university_admin'
        ? CampusOverviewCard(counts: _campusPlantCounts)
        : _buildQuickActionsCard();
    if (recentPlants == null) return actions;
    if (contentWidth >= 720 &&
        MediaQuery.textScalerOf(context).scale(1) < 1.6) {
      return EqualHeightCards(
        gap: AppSpacing.lg,
        children: [actions, recentPlants],
      );
    }

    return Column(
      children: [
        actions,

        const SizedBox(height: AppSpacing.lg),

        recentPlants,
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActionsCard() {
    final actions = <Widget>[];

    if (_canRegisterPlant) {
      actions.add(
        QuickActionButton(
          icon: Icons.add_circle_outline_rounded,

          title: 'Register New Plant',

          subtitle: 'Add a new plant to EcoTag',

          bgColor: AppColors.primaryContainer,

          iconColor: AppColors.green,

          onTap: () async {
            if (_currentCampusId == null || _currentCollegeId == null) {
              _showMessage(
                'Your account has no assigned campus or college.',
                error: true,
              );

              return;
            }

            final result = await Navigator.push(
              context,

              MaterialPageRoute(
                builder: (context) => RegisterPlantScreen(
                  userId: widget.userId,

                  username: _userName,

                  role: _role,

                  campusId: _currentCampusId!,

                  collegeId: _currentCollegeId!,
                ),
              ),
            );

            if (result == true) {
              _loadDashboardData();
            }
          },
        ),
      );
    }

    if (_canViewPlantList) {
      actions.add(
        QuickActionButton(
          icon: Icons.park_rounded,

          title: 'View Plant List',

          subtitle: 'Browse registered plants',

          bgColor: AppColors.secondaryContainer,

          iconColor: AppColors.secondary,

          onTap: () {
            Navigator.pushNamed(
              context,
              '/plant-list',
              arguments: {
                'user_id': widget.userId,

                'username': _userName,

                'role': _role,

                'campus_id': _currentCampusId,

                'college_id': _currentCollegeId,
              },
            );
          },
        ),
      );
    }

    if (_canGenerateReport) {
      actions.add(
        QuickActionButton(
          icon: Icons.assessment_outlined,

          title: 'Create Report',

          subtitle: 'Generate plant monitoring reports',

          bgColor: AppColors.infoContainer,

          iconColor: AppColors.info,

          onTap: () {
            Navigator.pushNamed(
              context,
              '/reports',
              arguments: {
                'user_id': widget.userId,

                'username': _userName,

                'role': _role,

                'campus_id': _currentCampusId,

                'college_id': _currentCollegeId,
              },
            );
          },
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Quick Actions',

            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'Common plant management tasks',

            style: TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.green,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (actions.isEmpty)
            const Text(
              'No available actions.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._addSpacing(actions),
        ],
      ),
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets) {
    final result = <Widget>[];

    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);

      if (i < widgets.length - 1) {
        result.add(const SizedBox(height: 9));
      }
    }

    return result;
  }

  // ============================================================
  // HEALTH CHART
  // ============================================================

  Widget _buildHealthChartCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Plant Health Overview',

            style: TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'Distribution of plant health status',

            style: TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.green,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          SizedBox(
            height: 180,

            child: Stack(
              alignment: Alignment.center,

              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,

                    sectionsSpace: 2,

                    centerSpaceRadius: 50,

                    sections: _buildPieSections(),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      '$_totalPlants',

                      style: const TextStyle(
                        color: AppColors.darkGreen,

                        fontSize: AppTypography.metric,

                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const Text(
                      'Total Plants',

                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,

              spacing: 14,

              runSpacing: 8,

              children: [
                _buildLegend(AppColors.chartHealthy, 'Healthy', _healthyCount),

                _buildLegend(
                  AppColors.chartAtRisk,
                  'Needs attention',
                  _dyingCount,
                ),

                _buildLegend(AppColors.chartDead, 'Dead', _deadCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    if (_totalPlants <= 0) {
      return [
        PieChartSectionData(
          value: 1,

          color: AppColors.border,

          radius: 20,

          showTitle: false,
        ),
      ];
    }

    return [
      PieChartSectionData(
        value: _healthyCount.toDouble(),

        color: AppColors.chartHealthy,

        radius: 22,

        showTitle: false,
      ),

      PieChartSectionData(
        value: _dyingCount.toDouble(),

        color: AppColors.chartAtRisk,

        radius: 20,

        showTitle: false,
      ),

      PieChartSectionData(
        value: _deadCount.toDouble(),

        color: AppColors.chartDead,

        radius: 20,

        showTitle: false,
      ),
    ];
  }

  // ============================================================
  // RECENT PLANTS
  // ============================================================

  Widget _buildResponsiveRecentPlants(double contentWidth) {
    return AppCard(
      child: RecentPlantsTable(
        plants: _recentPlants,
        onViewAll: _openPlantList,
      ),
    );
  }

  void _openPlantList() {
    Navigator.pushNamed(
      context,
      '/plant-list',
      arguments: {
        'user_id': widget.userId,
        'username': _userName,
        'role': _role,
        'campus_id': _currentCampusId,
        'college_id': _currentCollegeId,
      },
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _buildLegend(Color color, String title, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 8,
          height: 8,

          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 5),

        Text(
          '$title  $value',

          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double get _healthyPercent {
    if (_totalPlants == 0) {
      return 0;
    }

    return (_healthyCount / _totalPlants) * 100;
  }

  double get _deadPercent {
    if (_totalPlants == 0) {
      return 0;
    }

    return (_deadCount / _totalPlants) * 100;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: error ? Colors.red : AppColors.green,
      ),
    );
  }
}
