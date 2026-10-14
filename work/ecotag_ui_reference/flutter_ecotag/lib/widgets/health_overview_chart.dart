import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class HealthOverviewChart extends StatefulWidget {
  final DashboardStats? stats;
  final bool loading;

  const HealthOverviewChart({super.key, this.stats, this.loading = false});

  @override
  State<HealthOverviewChart> createState() => _HealthOverviewChartState();
}

class _HealthOverviewChartState extends State<HealthOverviewChart> {
  int _touched = -1;

  static const _colors = [
    AppColors.healthy,
    AppColors.warning,
    AppColors.danger,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _ChartSkeleton();

    final stats = widget.stats;
    if (stats == null) return const SizedBox.shrink();

    final data = [stats.healthyPlants, stats.atRiskPlants, stats.deadPlants];
    final labels = ['Healthy', 'Dying', 'Dead'];
    final total = stats.totalPlants;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.outline),
        boxShadow: const [BoxShadow(color: Color(0x062E7D32), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plant Health Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Distribution of plant health status',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: List.generate(3, (i) {
                      final isTouched = i == _touched;
                      return PieChartSectionData(
                        value: data[i].toDouble(),
                        color: _colors[i],
                        radius: isTouched ? 72 : 64,
                        title: '',
                        borderSide: isTouched
                            ? const BorderSide(color: Colors.white, width: 3)
                            : BorderSide.none,
                      );
                    }),
                    centerSpaceRadius: 56,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                          setState(() => _touched = -1);
                          return;
                        }
                        setState(() => _touched = response!.touchedSection!.touchedSectionIndex);
                      },
                    ),
                  ),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const Text(
                      'Total Plants',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      ['Healthy', 'Dying', 'Dead'][i],
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data[i]}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      padding: AppSpacing.cardPadding,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE8F5E8),
        highlightColor: const Color(0xFFF5FBF5),
        child: Column(
          children: [
            Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
