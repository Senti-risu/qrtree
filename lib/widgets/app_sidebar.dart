import 'package:flutter/material.dart';

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

  bool get _canRegisterPlant => role == 'college_admin';
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
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              'MANAGEMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
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
          const Spacer(),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, _NavItemData item) {
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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: active ? const Color(0xFFEAF6EE) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  data.icon,
                  size: 18,
                  color: active
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1A1A1A),
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
}
