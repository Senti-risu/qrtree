import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavDestination {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

const _destinations = [
  NavDestination(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
  ),
  NavDestination(
    id: 'register',
    label: 'Register Plant',
    icon: Icons.add_circle_outline_rounded,
    activeIcon: Icons.add_circle_rounded,
  ),
  NavDestination(
    id: 'plants',
    label: 'Plant List',
    icon: Icons.park_outlined,
    activeIcon: Icons.park_rounded,
  ),
  NavDestination(
    id: 'inspections',
    label: 'Inspections',
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check_rounded,
  ),
  NavDestination(
    id: 'reports',
    label: 'Reports',
    icon: Icons.assessment_outlined,
    activeIcon: Icons.assessment_rounded,
  ),
];

class AppSidebar extends StatelessWidget {
  final String activeId;
  final ValueChanged<String> onNavigate;
  final bool collapsed;
  final VoidCallback onToggle;

  const AppSidebar({
    super.key,
    required this.activeId,
    required this.onNavigate,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: collapsed ? 64 : 248,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.outline)),
        boxShadow: [BoxShadow(color: Color(0x062E7D32), blurRadius: 12, offset: Offset(2, 0))],
      ),
      child: Column(
        children: [
          // Section label
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MANAGEMENT',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryLight,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: _destinations.map((d) => _NavItem(
                      destination: d,
                      isActive: activeId == d.id,
                      collapsed: collapsed,
                      onTap: () => onNavigate(d.id),
                    )).toList(),
              ),
            ),
          ),

          // Collapse toggle
          const Divider(height: 1, color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.all(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: collapsed ? 0 : 12,
                ),
                child: Row(
                  mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Icon(
                      collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Collapse',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final NavDestination destination;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final collapsed = widget.collapsed;
    final bg = isActive
        ? AppColors.primaryContainer
        : _hovered
            ? const Color(0xFFF1F8F1)
            : Colors.transparent;

    return Tooltip(
      message: collapsed ? widget.destination.label : '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: collapsed ? 0 : 12,
            ),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isActive ? widget.destination.activeIcon : widget.destination.icon,
                    size: 18,
                    color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
