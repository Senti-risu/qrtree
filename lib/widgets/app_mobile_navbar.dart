import 'package:flutter/material.dart';
import '../screens/inspections/reminder_settings_screen.dart';

import '../models/app_role.dart';
import '../screens/qr/qr_problem_reports_screen.dart';
import '../services/account_profile_service.dart';
import '../services/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_mobile_more_sheet.dart';
import 'app_navigation_guard.dart';

class AppMobileNavbar extends StatelessWidget {
  final String activeRoute;
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final bool canScanQr;
  final String displayName;
  final String displayRole;

  const AppMobileNavbar({
    super.key,
    required this.activeRoute,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.canScanQr = false,
    this.displayName = '',
    this.displayRole = '',
  });

  Map<String, dynamic> get _userArguments => {
    'user_id': userId,
    'username': username,
    'role': role,
    'campus_id': campusId,
    'college_id': collegeId,
  };

  bool get _canViewPlantList => const {
    'super_admin',
    'university_admin',
    'campus_admin',
    'college_admin',
    'inspection_team',
  }.contains(role);

  bool get _canViewInspections =>
      role == 'inspection_team' || role == 'college_admin';

  List<_MobileDestination> get _destinations {
    if (role == 'super_admin') {
      return const [
        _MobileDestination(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          route: '/super-admin',
        ),
        _MobileDestination(
          icon: Icons.manage_accounts_rounded,
          label: 'Accounts',
          route: '/manage-accounts',
        ),
        _MobileDestination(
          icon: Icons.eco_rounded,
          label: 'Plants',
          route: '/plant-list',
        ),
        _MobileDestination(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          isMore: true,
        ),
      ];
    }

    return [
      const _MobileDestination(
        icon: Icons.home_rounded,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      if (_canViewPlantList)
        const _MobileDestination(
          icon: Icons.eco_rounded,
          label: 'Plants',
          route: '/plant-list',
        ),
      if (_canViewInspections)
        const _MobileDestination(
          icon: Icons.history_rounded,
          label: 'Inspections',
          route: '/inspections',
        )
      else
        const _MobileDestination(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          route: '/reports',
        ),
      const _MobileDestination(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        isMore: true,
      ),
    ];
  }

  bool get _isMoreActive {
    if (role == 'college_admin') {
      return const {
        '/qr-management',
        '/inspection-accounts',
        '/reports',
        '/activity-log',
      }.contains(activeRoute);
    }
    if (role == 'inspection_team') {
      return activeRoute == '/reports';
    }
    if (const {
      'super_admin',
      'university_admin',
      'campus_admin',
    }.contains(role)) {
      return activeRoute == '/activity-log' ||
          (role == 'university_admin' &&
              const {
                '/plant-classifications',
                '/inspection-schedule',
              }.contains(activeRoute));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleAdjustment = (textScale - 1).clamp(0.0, 1.0).toDouble();
    final contentHeight = 68.0 + (18 * scaleAdjustment);

    return BottomAppBar(
      height: contentHeight + bottomInset,
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      shape: canScanQr ? const CircularNotchedRectangle() : null,
      notchMargin: 7,
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++) ...[
              Expanded(
                child: _navButton(
                  context,
                  destination: destinations[index],
                  height: contentHeight,
                ),
              ),
              if (canScanQr && index == 1) const SizedBox(width: 56),
            ],
            // Super Admin currently has three destinations. Reserve a fourth
            // destination-sized space so the center scanner stays visually
            // centered with two navigation actions on either side.
            if (canScanQr && destinations.length.isOdd) const Spacer(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAV BUTTON
  // ============================================================

  Widget _navButton(
    BuildContext context, {
    required _MobileDestination destination,
    required double height,
  }) {
    final active = destination.isMore
        ? _isMoreActive
        : activeRoute == destination.route ||
              (destination.route == '/plant-list' &&
                  activeRoute == '/register-plant');
    final color = active ? AppColors.green : AppColors.inactiveNav;

    return Semantics(
      button: true,
      selected: active,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: () async {
            if (destination.isMore) {
              await _openMore(context);
              return;
            }
            if (destination.route != null && activeRoute != destination.route) {
              _navigate(context, destination.route!);
            }
          },
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: AppRadii.fullyRounded,
                  ),
                  child: Icon(destination.icon, size: 24, color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMore(BuildContext context) async {
    final action = await showAppMobileMoreSheet(
      context,
      displayName: _resolvedDisplayName,
      displayRole: _resolvedDisplayRole,
      role: role,
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case AppMobileMoreAction.reminders:
        if (!await AppNavigationGuard.confirm(context) || !context.mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const ReminderSettingsScreen(),
          ),
        );
        return;
      case AppMobileMoreAction.profile:
        final profileService = AccountProfileService();
        await showAppMobileProfileSheet(
          context,
          username: username,
          displayName: _resolvedDisplayName,
          displayRole: _resolvedDisplayRole,
          role: role,
          loadScopeNames: () => profileService.loadScopeNames(
            campusId: campusId,
            collegeId: collegeId,
          ),
        );
        return;
      case AppMobileMoreAction.plantClassifications:
        _navigate(context, '/plant-classifications');
        return;
      case AppMobileMoreAction.inspectionSchedule:
        _navigate(context, '/inspection-schedule');
        return;
      case AppMobileMoreAction.registerPlant:
        _navigate(context, '/register-plant');
        return;
      case AppMobileMoreAction.qrManagement:
        _navigate(context, '/qr-management');
        return;
      case AppMobileMoreAction.qrReports:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                QrProblemReportsScreen(canReview: role == 'college_admin'),
          ),
        );
        return;
      case AppMobileMoreAction.userManagement:
        _navigate(context, '/inspection-accounts');
        return;
      case AppMobileMoreAction.reports:
        _navigate(context, '/reports');
        return;
      case AppMobileMoreAction.activityLog:
        _navigate(context, '/activity-log');
        return;
      case AppMobileMoreAction.logout:
        if (!await AppNavigationGuard.confirm(context) || !context.mounted) {
          return;
        }
        final shouldLogout = await _confirmLogout(context);
        if (!shouldLogout || !context.mounted) return;
        try {
          await AppSession.end();
        } catch (_) {
          if (context.mounted) {
            _showError(
              context,
              'This device could not remove the saved sign-in. Please try logging out again.',
            );
          }
          return;
        }
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
    }
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        title: const Text('Sign out of EcoTag?'),
        content: const Text(
          'You will return to the login screen. Any information you have not '
          'saved may be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _navigate(BuildContext context, String route) async {
    if (const {
      '/register-plant',
      '/qr-management',
      '/inspection-accounts',
    }.contains(route)) {
      final allowed = route == '/register-plant'
          ? RoleCapabilities.fromValue(role).canRegisterPlants
          : role == 'college_admin';
      if (!allowed) {
        _showError(context, 'Only College Admin can use this feature.');
        return;
      }
      if (campusId == null || collegeId == null) {
        _showError(context, 'Your account has no assigned campus or college.');
        return;
      }
    }

    if (route == '/plant-classifications' && role != 'university_admin') {
      _showError(context, 'University Admin access is required.');
      return;
    }

    if (route == '/inspections' && !_canViewInspections) {
      _showError(context, 'You do not have permission to view inspections.');
      return;
    }

    if (!await AppNavigationGuard.confirm(context) || !context.mounted) return;
    Navigator.pushReplacementNamed(context, route, arguments: _userArguments);
  }

  String get _resolvedDisplayName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    return username.trim();
  }

  String get _resolvedDisplayRole {
    if (displayRole.trim().isNotEmpty) return displayRole.trim();
    final appRole = AppRole.fromValue(role);
    return appRole == AppRole.unknown ? role.trim() : appRole.label;
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
  }
}

class _MobileDestination {
  final IconData icon;
  final String label;
  final String? route;
  final bool isMore;

  const _MobileDestination({
    required this.icon,
    required this.label,
    this.route,
    this.isMore = false,
  });
}
