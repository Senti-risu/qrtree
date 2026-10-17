import 'package:flutter/material.dart';
import '../models/app_role.dart';
import 'app_navigation_guard.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

class AppSidebar extends StatelessWidget {
  final String activeRoute;
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const AppSidebar({
    super.key,
    this.activeRoute = '/dashboard',
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  bool get _canRegisterPlant =>
      RoleCapabilities.fromValue(role).canRegisterPlants;
  bool get _canManageQrCodes => role == 'college_admin';
  bool get _canViewPlantList =>
      role == 'super_admin' ||
      role == 'university_admin' ||
      role == 'campus_admin' ||
      role == 'college_admin' ||
      role == 'inspection_team';
  bool get _canViewReports => _canViewPlantList;
  bool get _canViewInspections =>
      role == 'college_admin' || role == 'inspection_team';
  bool get _canViewActivityLog => const {
    'super_admin',
    'university_admin',
    'campus_admin',
    'college_admin',
  }.contains(role);

  Map<String, dynamic> get _userArguments => {
    'user_id': userId,
    'username': username,
    'role': role,
    'campus_id': campusId,
    'college_id': collegeId,
  };

  List<_NavItemData> get _navItems => role == 'super_admin'
      ? [
          const _NavItemData(
            route: '/super-admin',
            icon: Icons.grid_view_rounded,
            label: 'Dashboard',
          ),
          const _NavItemData(
            route: '/manage-accounts',
            icon: Icons.manage_accounts_outlined,
            label: 'Manage Accounts',
          ),
          const _NavItemData(
            route: '/activity-log',
            icon: Icons.history_rounded,
            label: 'Activity Log',
          ),
        ]
      : [
          const _NavItemData(
            route: '/dashboard',
            icon: Icons.grid_view_rounded,
            label: 'Dashboard',
          ),
          if (_canRegisterPlant)
            const _NavItemData(
              route: '/register-plant',
              icon: Icons.add_circle_outline,
              label: 'Register Plant',
            ),
          if (_canManageQrCodes)
            const _NavItemData(
              route: '/qr-management',
              icon: Icons.qr_code_2_rounded,
              label: 'QR Management',
            ),
          if (role == 'college_admin')
            const _NavItemData(
              route: '/inspection-accounts',
              icon: Icons.groups_2_outlined,
              label: 'Inspection Accounts',
            ),
          _NavItemData(
            route: '/plant-list',
            icon: Icons.eco_outlined,
            label: 'Plant List',
            enabled: _canViewPlantList,
          ),
          if (_canViewInspections)
            const _NavItemData(
              route: '/inspections',
              icon: Icons.fact_check_outlined,
              label: 'Inspections',
            ),
          _NavItemData(
            route: '/reports',
            icon: Icons.bar_chart_outlined,
            label: 'Reports',
            enabled: _canViewReports,
          ),
          if (_canViewActivityLog)
            const _NavItemData(
              route: '/activity-log',
              icon: Icons.history_rounded,
              label: 'Activity Log',
            ),
        ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.navbarBorder)),
      ),
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              'MANAGEMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final item in _navItems)
            _NavItem(
              data: item,
              active: item.route == activeRoute,
              onTap: () => _handleNavigation(context, item),
            ),
        ],
      ),
    );
  }

  Future<void> _handleNavigation(
    BuildContext context,
    _NavItemData item,
  ) async {
    if (item.route == activeRoute) return;

    if (!item.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.label} is not available.')),
      );
      return;
    }

    if ((item.route == '/register-plant' ||
            item.route == '/qr-management' ||
            item.route == '/inspection-accounts') &&
        (campusId == null || collegeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has no assigned campus or college.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!await AppNavigationGuard.confirm(context) || !context.mounted) return;
    Navigator.pushReplacementNamed(
      context,
      item.route,
      arguments: _userArguments,
    );
  }
}

class _NavItemData {
  final String route;
  final IconData icon;
  final String label;
  final bool enabled;
  const _NavItemData({
    required this.route,
    required this.icon,
    required this.label,
    this.enabled = true,
  });
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: active ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: AppRadii.medium,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.medium,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppLayout.minimumTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    data.icon,
                    size: 20,
                    color: active ? AppColors.green : AppColors.inactiveNav,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      data.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.green : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
