import 'package:flutter/material.dart';
import '../../../../theme/app_typography.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_card.dart';

class ReportTableCard extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String emptyMessage;

  const ReportTableCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records available.',
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 9),
          const Divider(),
          const SizedBox(height: 5),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 36,
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.background,
                ),
                columns: columns
                    .map(
                      (column) => DataColumn(
                        label: Text(
                          column,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                    .toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .asMap()
                            .entries
                            .map(
                              (entry) => DataCell(
                                SizedBox(
                                  width: entry.key == 0 ? 260 : 100,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
