import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_card.dart';
import 'dashboard widgets/dashboard_stat_card.dart';
import 'dashboard widgets/dashboard_page_header.dart';
import 'dashboard widgets/campus_overview_card.dart';
import 'dashboard widgets/quick_action_button.dart';
import 'dashboard widgets/recent_plants_table.dart';

import 'register_plants.dart';

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
    return _role == 'college_admin';
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

        campus (
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

        campus (
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

      onRefresh: _loadDashboardData,

      showQrButton: true,

      onQrPressed: () {
        Navigator.pushNamed(
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
      },

      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              DashboardPageHeader(
                description: _dashboardDescription,
                userRole: _userRole,
                onRefresh: _loadDashboardData,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_role == 'college_admin' || _role == 'inspection_team') &&
                _dyingCount > 0) ...[
              _buildPriorityTaskCard(),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildResponsiveStats(contentWidth),

            const SizedBox(height: AppSpacing.xl),

            _buildResponsiveAnalytics(contentWidth),

            const SizedBox(height: AppSpacing.xl),

            _buildResponsiveRecentPlants(contentWidth),
          ],
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

  void _openNeedsAttention() {
    Navigator.pushNamed(
      context,
      '/plant-list',
      arguments: {
        'user_id': widget.userId,
        'username': _userName,
        'role': _role,
        'campus_id': _currentCampusId,
        'college_id': _currentCollegeId,
        'health_filter': 'Needs attention',
      },
    );
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

    final columns = largeText && !AppBreakpoints.isDesktop(contentWidth)
        ? 1
        : AppBreakpoints.isDesktop(contentWidth)
        ? 4
        : contentWidth >= 360
        ? 2
        : 1;

    final totalGap = gap * (columns - 1);

    final cardWidth = (contentWidth - totalGap) / columns;

    final cards = <Widget>[
      DashboardStatCard(
        title: 'Total Plants',

        value: '$_totalPlants',

        subtext: _totalPlantSubtitle,

        icon: Icons.park_rounded,

        iconBgColor: AppColors.primaryContainer,

        iconColor: AppColors.green,
      ),

      DashboardStatCard(
        title: 'Healthy Plants',

        value: '$_healthyCount',

        subtext: _totalPlants == 0
            ? ''
            : '${_healthyPercent.toStringAsFixed(0)}% of total plants',

        icon: Icons.eco_rounded,

        iconBgColor: AppColors.primaryContainer,

        iconColor: AppColors.green,

        percentage: _totalPlants == 0
            ? ''
            : '${_healthyPercent.toStringAsFixed(0)}%',

        progress: _totalPlants == 0 ? 0 : _healthyPercent / 100,
      ),

      DashboardStatCard(
        title: 'At Risk',

        value: '$_dyingCount',

        subtext: 'Requires inspection',

        icon: Icons.warning_amber_rounded,

        iconBgColor: AppColors.warningContainer,

        iconColor: AppColors.warningAccent,
      ),

      DashboardStatCard(
        title: 'Dead Plants',

        value: '$_deadCount',

        subtext: _totalPlants == 0
            ? ''
            : '${_deadPercent.toStringAsFixed(1)}% of total plants',

        icon: Icons.local_florist_outlined,

        iconBgColor: AppColors.dangerContainer,

        iconColor: AppColors.danger,
      ),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,

      children: cards
          .map((card) => SizedBox(width: cardWidth, child: card))
          .toList(),
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  Widget _buildResponsiveAnalytics(double contentWidth) {
    if (!AppBreakpoints.isPhone(contentWidth)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: _role == 'university_admin'
                ? CampusOverviewCard(counts: _campusPlantCounts)
                : _buildQuickActionsCard(),
          ),

          const SizedBox(width: AppSpacing.lg),

          Expanded(child: _buildHealthChartCard()),
        ],
      );
    }

    return Column(
      children: [
        if (_role == 'university_admin')
          CampusOverviewCard(counts: _campusPlantCounts)
        else
          _buildQuickActionsCard(),

        const SizedBox(height: AppSpacing.lg),

        _buildHealthChartCard(),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'Common plant management tasks',

            style: TextStyle(fontSize: 10, color: AppColors.green),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'Distribution of plant health status',

            style: TextStyle(fontSize: 10, color: AppColors.green),
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

                        fontSize: 22,

                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const Text(
                      'Total Plants',

                      style: TextStyle(color: AppColors.green, fontSize: 9),
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
    return RecentPlantsTable(plants: _recentPlants, onViewAll: _openPlantList);
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

          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
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
