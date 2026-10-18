import 'package:flutter/material.dart';

import '../../services/guest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/guest_mobile_navbar.dart';
import 'guest_qr_scanner_screen.dart';

/// A public, read-only overview. It deliberately does not reuse [AppShell],
/// which is reserved for authenticated administrators and inspection teams.
class GuestDashboardScreen extends StatefulWidget {
  const GuestDashboardScreen({
    super.key,
    required this.visitId,
    this.guestName,
    this.service,
  });

  final int visitId;
  final String? guestName;
  final GuestService? service;

  @override
  State<GuestDashboardScreen> createState() => _GuestDashboardScreenState();
}

class _GuestDashboardScreenState extends State<GuestDashboardScreen> {
  late final GuestService _service;
  GuestDashboardSummary? _summary;
  String? _error;
  bool _isLoading = true;
  int _mobileDestination = 0;

  String get _displayName {
    final value = widget.guestName?.trim() ?? '';
    if (value.isEmpty) return 'Guest';
    return value.length <= 60 ? value : value.substring(0, 60);
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GuestService();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _service.loadDashboardSummary(
        visitId: widget.visitId,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(
          error,
          fallback:
              'Public EcoTag information could not be loaded. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  void _leaveGuestView() {
    Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
  }

  void _openAdminAccess() {
    Navigator.pushNamedAndRemoveUntil(context, '/access', (_) => false);
  }

  Future<void> _openScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GuestQrScannerScreen(visitId: widget.visitId, service: _service),
      ),
    );
  }

  Future<void> _confirmLeaveGuestView() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        title: const Text('End guest visit?'),
        content: const Text(
          'You will return to the EcoTag welcome page. Your optional name is '
          'not saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End visit'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) _leaveGuestView();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width);
    final showingAccount = mobile && _mobileDestination == 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(),
            const SizedBox(width: 10),
            Text(
              showingAccount ? 'Guest Account' : 'EcoTag',
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          if (!mobile)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _openAdminAccess,
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 19),
                label: const Text('Admin sign in'),
              ),
            ),
          if (!mobile) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: _confirmLeaveGuestView,
              tooltip: 'Exit guest view',
              icon: const Icon(Icons.logout_rounded, color: AppColors.green),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: showingAccount ? _accountContent() : _homeContent(mobile),
      ),
      floatingActionButton: mobile
          ? FloatingActionButton(
              onPressed: _openScanner,
              tooltip: 'Scan EcoTag',
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 5,
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 29,
                semanticLabel: 'Scan EcoTag',
              ),
            )
          : null,
      floatingActionButtonLocation: mobile
          ? FloatingActionButtonLocation.centerDocked
          : null,
      bottomNavigationBar: mobile
          ? GuestMobileNavbar(
              selectedIndex: _mobileDestination,
              onHome: () => setState(() => _mobileDestination = 0),
              onAccount: () => setState(() => _mobileDestination = 1),
            )
          : null,
    );
  }

  Widget _homeContent(bool mobile) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_error != null) {
      return AppErrorState(
        title: 'Unable to open the guest dashboard',
        message: _error!,
        onRetry: _loadSummary,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      color: AppColors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 28,
          mobile ? 16 : 24,
          mobile ? 16 : 28,
          mobile ? 108 : 36,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: _dashboardContent(_summary!),
          ),
        ),
      ),
    );
  }

  Widget _accountContent() {
    final initial = _displayName.isEmpty
        ? 'G'
        : _displayName.substring(0, 1).toUpperCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.darkGreen,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Guest · View only',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your guest access',
                      style: TextStyle(
                        color: AppColors.darkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _GuestAccessRow(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan and view',
                      body:
                          'Scan an assigned EcoTag label to see its public plant profile.',
                    ),
                    const _GuestAccessRow(
                      icon: Icons.visibility_outlined,
                      title: 'Read-only access',
                      body:
                          'Guests cannot register, edit, inspect, archive, or manage plants.',
                    ),
                    _GuestAccessRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      body: widget.guestName?.trim().isNotEmpty == true
                          ? 'Your name is kept only on this device during this visit. Only your age was recorded for anonymous statistics.'
                          : 'Only your age was recorded for anonymous visitor statistics.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openAdminAccess,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin or Inspection Team sign in'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _confirmLeaveGuestView,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('End guest visit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardContent(GuestDashboardSummary summary) {
    final mobile = AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = AppBreakpoints.isPhone(constraints.maxWidth);
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Welcome, $_displayName',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(color: AppColors.darkGreen),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explore a public overview of CSU campus plants and learn how EcoTag supports plant monitoring.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 16),
                    if (mobile) ...[
                      const Text(
                        'To view a plant, scan the EcoTag label attached to it.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan a plant label'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: _openAdminAccess,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Admin or Inspection Team sign in'),
                      ),
                  ],
                );
              }

              return heading;
            },
          ),
        ),
        const SizedBox(height: 18),
        _summaryCards(summary),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = <Widget>[
              _healthOverview(summary),
              _aboutEcoTag(summary),
            ];
            if (AppBreakpoints.isDesktop(constraints.maxWidth)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              );
            }
            return Column(
              children: [cards[0], const SizedBox(height: 16), cards[1]],
            );
          },
        ),
      ],
    );
  }

  Widget _summaryCards(GuestDashboardSummary summary) {
    final cards = [
      _PublicStat(
        title: 'Registered Plants',
        value: summary.totalPlants,
        description: 'Active EcoTag plant records',
        icon: Icons.park_rounded,
        color: AppColors.green,
        background: AppColors.primaryContainer,
      ),
      _PublicStat(
        title: 'Healthy Plants',
        value: summary.healthyPlants,
        description: 'Currently recorded as healthy',
        icon: Icons.eco_rounded,
        color: AppColors.healthy,
        background: AppColors.primaryContainer,
      ),
      _PublicStat(
        title: 'Need Attention',
        value: summary.atRiskPlants,
        description: 'Marked for closer monitoring',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        background: AppColors.warningContainer,
      ),
      _PublicStat(
        title: 'Recorded Dead',
        value: summary.deadPlants,
        description: 'Historical monitoring status',
        icon: Icons.local_florist_outlined,
        color: AppColors.danger,
        background: AppColors.dangerContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final columns =
            largeText && !AppBreakpoints.isDesktop(constraints.maxWidth)
            ? 1
            : AppBreakpoints.isDesktop(constraints.maxWidth)
            ? 4
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _healthOverview(GuestDashboardSummary summary) {
    final healthyRatio = summary.totalPlants == 0
        ? 0.0
        : (summary.healthyPlants / summary.totalPlants).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.monitor_heart_outlined,
            title: 'Plant health overview',
          ),
          const SizedBox(height: 14),
          Text(
            summary.totalPlants == 0
                ? 'Plant monitoring information will appear here once records are available.'
                : '${(healthyRatio * 100).toStringAsFixed(0)}% of active plant records are currently marked healthy.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                '${(healthyRatio * 100).toStringAsFixed(0)} percent healthy plants',
            child: LinearProgressIndicator(
              value: healthyRatio,
              minHeight: 12,
              color: AppColors.healthy,
              backgroundColor: AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _LegendDot(
                color: AppColors.healthy,
                label: 'Healthy ${summary.healthyPlants}',
              ),
              _LegendDot(
                color: AppColors.warning,
                label: 'Needs attention ${summary.atRiskPlants}',
              ),
              _LegendDot(
                color: AppColors.danger,
                label: 'Dead ${summary.deadPlants}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aboutEcoTag(GuestDashboardSummary summary) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.info_outline_rounded,
            title: 'About EcoTag',
          ),
          const SizedBox(height: 14),
          const Text(
            'EcoTag is CSU’s plant profiling and monitoring system. It helps authorized teams register campus plants, connect records to QR tags, and follow plant health over time.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      '${summary.campusCount} CSU ${summary.campusCount == 1 ? 'campus is' : 'campuses are'} represented in this public overview.',
                      style: const TextStyle(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestAccessRow extends StatelessWidget {
  const _GuestAccessRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.green, size: 22),
        ),
        const SizedBox(width: 12),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
    );
  }
}

class _PublicStat extends StatelessWidget {
  const _PublicStat({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String title;
  final int value;
  final String description;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        label: '$title: $value. $description',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.darkGreen,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
