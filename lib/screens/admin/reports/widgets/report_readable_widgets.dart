import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';

class ReportDetailField extends StatelessWidget {
  const ReportDetailField({
    super.key,
    required this.label,
    required this.value,
    required this.width,
  });
  final String label, value;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class ReportHealthDistribution extends StatelessWidget {
  const ReportHealthDistribution({super.key, required this.values});
  final List<(String, int, Color)> values;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            centerSpaceRadius: 46,
            sectionsSpace: 3,
            sections: values
                .where((item) => item.$2 > 0)
                .map(
                  (item) => PieChartSectionData(
                    value: item.$2.toDouble(),
                    color: item.$3,
                    radius: 34,
                    showTitle: false,
                  ),
                )
                .toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: values
            .where((item) => item.$2 > 0)
            .map(
              (item) => Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.circle, size: 10, color: item.$3),
                      ),
                    ),
                    TextSpan(text: '${item.$1}  ${item.$2}'),
                  ],
                ),
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}
