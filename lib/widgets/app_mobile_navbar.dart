import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../services/account_profile_service.dart';
import '../services/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_mobile_more_sheet.dart';

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
        '/register-plant',
        '/qr-management',
        '/inspection-accounts',
        '/reports',
        '/activity-log',
      }.contains(activeRoute);
    }
    if (role == 'inspection_team') return activeRoute == '/reports';
    if (const {
      'super_admin',
      'university_admin',
      'campus_admin',
    }.contains(role)) {
      return activeRoute == '/activity-log';
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
        : activeRoute == destination.route;
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
            if (!active && destination.route != null) {
              _navigate(context, destination.route!);
            }
          },
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, size: 24, color: color),
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
      case AppMobileMoreAction.registerPlant:
        _navigate(context, '/register-plant');
        return;
      case AppMobileMoreAction.qrManagement:
        _navigate(context, '/qr-management');
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
      case AppMobileMoreAction.help:
        await _showHelp(context);
        return;
      case AppMobileMoreAction.logout:
        final shouldLogout = await _confirmLogout(context);
        if (!shouldLogout || !context.mounted) return;
        await AppSession.end();
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
    }
  }

  Future<void> _showHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'How to use EcoTag',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Start with the task you need. EcoTag will only show actions allowed for your account.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _HelpStep(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan a label',
            body:
                'Use the center Scan button, place the QR inside the frame, and follow the result shown.',
          ),
          const _HelpStep(
            icon: Icons.local_florist_outlined,
            title: 'Find a plant',
            body:
                'Open Plants, search by name or tag, then tap a card to view its details.',
          ),
          const _HelpStep(
            icon: Icons.fact_check_outlined,
            title: 'Record an inspection',
            body:
                'Confirm the plant, add a current photo, select its condition, and save your observations.',
          ),
          const _HelpStep(
            icon: Icons.support_agent_rounded,
            title: 'Need more help?',
            body:
                'Contact your College Admin. Open My Profile to confirm your role, campus, and college.',
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    ),
  );

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
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigate(BuildContext context, String route) {
    if (const {
      '/register-plant',
      '/qr-management',
      '/inspection-accounts',
    }.contains(route)) {
      if (role != 'college_admin') {
        _showError(context, 'Only College Admin can use this feature.');
        return;
      }
      if (campusId == null || collegeId == null) {
        _showError(context, 'Your account has no assigned campus or college.');
        return;
      }
    }

    if (route == '/inspections' && !_canViewInspections) {
      _showError(context, 'You do not have permission to view inspections.');
      return;
    }

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

class _HelpStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadii.medium,
          ),
          child: Icon(icon, color: AppColors.green),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
