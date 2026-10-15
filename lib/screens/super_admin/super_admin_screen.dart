import 'package:flutter/material.dart';

import '../../models/admin_account.dart';
import '../../models/app_role.dart';
import '../../services/super_admin_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
  });
  final int userId;
  final String username;
  final String role;
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _service = SuperAdminService();
  List<AdminAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await _service.getAccounts(widget.userId);
      if (mounted) setState(() => _accounts = accounts);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _arguments => {
    'user_id': widget.userId,
    'username': widget.username,
    'role': widget.role,
  };

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/super-admin',
      mobileTitle: 'Dashboard',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      userRole: AppRole.superAdmin.label,
      onRefresh: _load,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              AppPageHeader(
                title: 'Dashboard',
                subtitle: 'Overview of EcoTag administrator accounts.',
                trailing: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/manage-accounts',
                    arguments: _arguments,
                  ),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Manage Accounts'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else
              _Metrics(accounts: _accounts),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.accounts});
  final List<AdminAccount> accounts;
  @override
  Widget build(BuildContext context) {
    int count(String role) => accounts.where((a) => a.role == role).length;
    final metrics = [
      ('Total Accounts', accounts.length, Icons.people_alt_outlined),
      (
        'Active Accounts',
        accounts.where((a) => a.isActive).length,
        Icons.verified_user_outlined,
      ),
      (
        'University Admins',
        count('university_admin'),
        Icons.account_balance_outlined,
      ),
      ('Campus Admins', count('campus_admin'), Icons.location_city_outlined),
      ('College Admins', count('college_admin'), Icons.school_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppBreakpoints.isDesktop(constraints.maxWidth)
            ? 3
            : AppBreakpoints.isTablet(constraints.maxWidth)
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: metrics
              .map(
                (m) => SizedBox(
                  width: width,
                  child: AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.primaryContainer,
                          child: Icon(m.$3, color: AppColors.green),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m.$2}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                            Text(
                              m.$1,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 10),
          const Text(
            'Unable to load account overview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
