import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;

  const AppHeader({super.key, required this.onMenuTap});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
        boxShadow: [BoxShadow(color: Color(0x0A2E7D32), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Hamburger
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
              tooltip: 'Toggle sidebar',
            ),
            const SizedBox(width: 8),
            // Logo
            _EcoTagLogo(),
            const Spacer(),
            // User profile
            _UserProfile(),
          ],
        ),
      ),
    );
  }
}

class _EcoTagLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EcoTag',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              'Campus Plant Profiling System',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final user = provider.currentUser;
    final name = user?.username ?? 'Delacruz, Jumi';
    final role = user?.role.label ?? 'College Admin';
    final initials = name.split(',').first.trim().isNotEmpty
        ? name.split(',').first.trim().substring(0, 1).toUpperCase()
        : 'U';

    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline_rounded, size: 18),
          child: const Text('My Profile'),
          onPressed: () {},
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.settings_outlined, size: 18),
          child: const Text('Account Settings'),
          onPressed: () {},
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
          child: const Text('Logout', style: TextStyle(color: Colors.red)),
          onPressed: () => provider.signOut(),
        ),
      ],
      builder: (_, controller, child) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(role, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
