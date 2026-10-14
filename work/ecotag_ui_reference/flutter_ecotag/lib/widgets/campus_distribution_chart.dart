import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class CampusDistributionChart extends StatefulWidget {
  final List<CampusData> data;
  final bool loading;

  const CampusDistributionChart({super.key, required this.data, this.loading = false});

  @override
  State<CampusDistributionChart> createState() => _CampusDistributionChartState();
}

class _CampusDistributionChartState extends State<CampusDistributionChart> {
  int _touched = -1;

  static const _barColors = [
    Color(0xFF2E7D32),
    Color(0xFF43A047),
    Color(0xFF66BB6A),
    Color(0xFFA5D6A7),
    Color(0xFFC8E6C9),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _BarChartSkeleton();

    final maxVal = widget.data.isEmpty
        ? 1
        : widget.data.map((e) => e.count).reduce((a, b) => a > b ? a : b);

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
          Text('Plants by Campus', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Distribution across university campuses',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.25,
                barGroups: widget.data.asMap().entries.map((e) {
                  final isTouched = e.key == _touched;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.count.toDouble(),
                        color: _barColors[e.key % _barColors.length],
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.25,
                          color: const Color(0xFFF0F9F0),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: isTouched ? [0] : [],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions || response?.spot == null) {
                      setState(() => _touched = -1);
                      return;
                    }
                    setState(() => _touched = response!.spot!.touchedBarGroupIndex);
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${widget.data[groupIndex].campus}\n${rod.toY.toInt()} plants',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= widget.data.length) return const SizedBox.shrink();
                        final label = widget.data[idx].campus.split(' ').last;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.outline, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartSkeleton extends StatelessWidget {
  const _BarChartSkeleton();

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
            Container(width: double.infinity, height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          ],
        ),
      ),
    );
  }
}
