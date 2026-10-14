import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/health_overview_chart.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_plants_table.dart';
import '../widgets/recent_inspections_card.dart';
import '../widgets/campus_distribution_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final isLoading = provider.isLoading;
    final data = provider.data;
    final error = provider.errorMessage;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Overview of campus plants and environmental monitoring',
                      style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Last updated: Today, 9:30 AM',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                    tooltip: 'Refresh',
                    onPressed: provider.fetchDashboard,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Error banner
          if (error != null) ...[
            _ErrorBanner(message: error, onRetry: provider.fetchDashboard),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Stats cards
          _StatsRow(stats: data?.stats, loading: isLoading),
          const SizedBox(height: AppSpacing.lg),

          // Analytics row
          _AnalyticsRow(stats: data?.stats, loading: isLoading),
          const SizedBox(height: AppSpacing.lg),

          // Recent plants
          RecentPlantsTable(
            plants: data?.recentPlants ?? [],
            loading: isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bottom row
          _BottomRow(data: data, loading: isLoading),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DashboardStats? stats;
  final bool loading;

  const _StatsRow({this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
          return _gridOf(
            List.generate(4, (_) => const DashboardStatCardSkeleton()),
            cols,
          );
        },
      );
    }

    final s = stats;
    final total = s?.totalPlants ?? 0;

    final cards = [
      DashboardStatCard(
        icon: Icons.park_rounded,
        title: 'Total Plants',
        value: '${s?.totalPlants ?? 0}',
        supporting: '+12 this month',
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryContainer,
        valueColor: const Color(0xFF1B5E20),
      ),
      DashboardStatCard(
        icon: Icons.eco_rounded,
        title: 'Healthy Plants',
        value: '${s?.healthyPlants ?? 0}',
        supporting: '${s?.healthyPercent.toStringAsFixed(0) ?? 85}% of total plants',
        iconColor: AppColors.healthy,
        iconBg: AppColors.healthyContainer,
        valueColor: const Color(0xFF1B5E20),
        progress: s?.healthyPercent ?? 85,
      ),
      DashboardStatCard(
        icon: Icons.warning_rounded,
        title: 'At Risk',
        value: '${s?.atRiskPlants ?? 0}',
        supporting: 'Requires inspection',
        iconColor: AppColors.warning,
        iconBg: AppColors.warningContainer,
        valueColor: const Color(0xFFE65100),
      ),
      DashboardStatCard(
        icon: Icons.local_florist_outlined,
        title: 'Dead Plants',
        value: '${s?.deadPlants ?? 0}',
        supporting: total > 0
            ? '${((s?.deadPlants ?? 0) / total * 100).toStringAsFixed(1)}% of total plants'
            : '12.5% of total plants',
        iconColor: AppColors.danger,
        iconBg: AppColors.dangerContainer,
        valueColor: const Color(0xFFB71C1C),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
        return _gridOf(cards, cols);
      },
    );
  }

  Widget _gridOf(List<Widget> children, int cols) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      rows.add(Row(
        children: List.generate(cols, (j) {
          final idx = i + j;
          if (idx >= children.length) return const Expanded(child: SizedBox());
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: j == 0 ? 0 : 12),
              child: children[idx],
            ),
          );
        }),
      ));
      if (i + cols < children.length) const SizedBox(height: 12);
    }
    return Column(children: rows.expand((w) => [w, const SizedBox(height: 12)]).take(rows.length * 2 - 1).toList());
  }
}

class _AnalyticsRow extends StatelessWidget {
  final DashboardStats? stats;
  final bool loading;

  const _AnalyticsRow({this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 800;
      if (stacked) {
        return Column(children: [
          HealthOverviewChart(stats: stats, loading: loading),
          const SizedBox(height: 12),
          const QuickActionCard(),
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: HealthOverviewChart(stats: stats, loading: loading)),
          const SizedBox(width: 16),
          Expanded(child: const QuickActionCard()),
        ],
      );
    });
  }
}

class _BottomRow extends StatelessWidget {
  final DashboardData? data;
  final bool loading;

  const _BottomRow({this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 800;
      if (stacked) {
        return Column(children: [
          RecentInspectionsCard(inspections: data?.recentInspections ?? [], loading: loading),
          const SizedBox(height: 12),
          CampusDistributionChart(data: data?.campusDistribution ?? [], loading: loading),
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: RecentInspectionsCard(inspections: data?.recentInspections ?? [], loading: loading)),
          const SizedBox(width: 16),
          Expanded(child: CampusDistributionChart(data: data?.campusDistribution ?? [], loading: loading)),
        ],
      );
    });
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to load dashboard data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.danger)),
                Text(message, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
