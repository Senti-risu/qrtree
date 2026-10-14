import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sidebar.dart';
import 'dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _activePage = 'dashboard';
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  static const _sidebarWidth = 248.0;
  static const _collapsedWidth = 64.0;

  Widget _buildPage() {
    return switch (_activePage) {
      'dashboard' => const DashboardScreen(),
      _ => _PlaceholderPage(page: _activePage),
    };
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;
    final isTablet = screenWidth >= 720 && screenWidth < 1100;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: isMobile
          ? Drawer(
              width: _sidebarWidth,
              child: Column(
                children: [
                  const SizedBox(height: 68),
                  Expanded(
                    child: AppSidebar(
                      activeId: _activePage,
                      onNavigate: (page) {
                        setState(() => _activePage = page);
                        _scaffoldKey.currentState?.closeDrawer();
                      },
                      collapsed: false,
                      onToggle: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Column(
        children: [
          AppHeader(
            onMenuTap: isMobile
                ? () => _scaffoldKey.currentState?.openDrawer()
                : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          Expanded(
            child: Row(
              children: [
                if (!isMobile)
                  AppSidebar(
                    activeId: _activePage,
                    onNavigate: (page) => setState(() => _activePage = page),
                    collapsed: isTablet ? true : _sidebarCollapsed,
                    onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  ),
                Expanded(
                  child: _buildPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String page;

  const _PlaceholderPage({required this.page});

  String get _label => switch (page) {
        'register' => 'Register Plant',
        'plants' => 'Plant List',
        'inspections' => 'Inspections',
        'reports' => 'Reports',
        _ => page,
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(_label, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'This section is under development.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
