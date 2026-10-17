import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fill the desktop panel, retaining horizontal scrolling on narrow viewports.
class FullWidthDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double minimumWidth;

  const FullWidthDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minimumWidth = 760,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(
        context,
      ).scale(1).clamp(1.0, 1.6);
      final width = math.max(constraints.maxWidth, minimumWidth * textScale);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: DataTable(
            horizontalMargin: 16,
            columnSpacing: 24,
            dataRowMinHeight: 56,
            dataRowMaxHeight: double.infinity,
            headingRowColor: const WidgetStatePropertyAll(AppColors.background),
            columns: columns,
            rows: rows,
          ),
        ),
      );
    },
  );
}
