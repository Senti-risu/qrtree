import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'app_workspace_page.dart';

/// Keep page sections aligned while allowing short windows to scroll.
class InspectionQueueLayout extends StatelessWidget {
  const InspectionQueueLayout({
    super.key,
    this.header,
    required this.filters,
    required this.body,
  });
  final Widget? header;
  final Widget filters, body;
  @override
  Widget build(BuildContext context) =>
      AppWorkspacePage(header: header, tools: filters, body: body);
}

class InspectionQueueFilters extends StatelessWidget {
  const InspectionQueueFilters({
    super.key,
    required this.selected,
    required this.onSelected,
    this.search,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  final Widget? search;
  static const filters = {
    'action': 'Needs Action',
    'due_today': 'Due Today',
    'overdue': 'Overdue',
    'upcoming': 'Upcoming',
    'completed': 'Completed',
    'history': 'History',
  };
  static IconData icon(String value) => switch (value) {
    'action' => Icons.priority_high_rounded,
    'due_today' => Icons.today_rounded,
    'overdue' => Icons.warning_amber_rounded,
    'upcoming' => Icons.upcoming_rounded,
    'completed' => Icons.task_alt_rounded,
    _ => Icons.history_rounded,
  };
  @override
  Widget build(BuildContext context) => AppCard(
    mergeWithParent: true,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (search != null) ...[search!, const SizedBox(height: 12)],
        LayoutBuilder(
          builder: (context, constraints) {
            final chips = filters.entries.map((entry) {
              final active = selected == entry.key;
              final urgent = entry.key == 'action' || entry.key == 'overdue';
              final color = active
                  ? (urgent ? AppColors.danger : AppColors.green)
                  : AppColors.textSecondary;
              return ChoiceChip(
                selected: active,
                showCheckmark: false,
                avatar: Icon(icon(entry.key), size: 17, color: color),
                label: Text(entry.value),
                labelStyle: TextStyle(
                  fontSize: AppTypography.label,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
                selectedColor: urgent
                    ? AppColors.dangerContainer
                    : AppColors.primaryContainer,
                backgroundColor: AppColors.background,
                side: BorderSide(
                  color: active
                      ? color.withValues(alpha: .45)
                      : AppColors.border,
                ),
                onSelected: (_) => onSelected(entry.key),
              );
            }).toList();
            if (constraints.maxWidth >= 720) {
              return Wrap(spacing: 8, runSpacing: 8, children: chips);
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    chips[i],
                  ],
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

class InspectionQueueEmptyState extends StatelessWidget {
  const InspectionQueueEmptyState({
    super.key,
    required this.filter,
    required this.onNext,
  });
  final String filter;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => AppEmptyState(
    title: switch (filter) {
      'action' => 'No inspections need attention',
      'due_today' => 'No inspections due today',
      'overdue' => 'No overdue inspections',
      'upcoming' => 'No upcoming inspections',
      'completed' => 'No recent completions',
      _ => 'No inspections found',
    },
    message: filter == 'completed'
        ? 'Completed inspections from the last 30 days will appear here.'
        : filter == 'action'
        ? 'There are no overdue or due-today inspections.'
        : 'Plants will appear here when their schedule matches this view.',
    icon: Icons.event_available_outlined,
    action: OutlinedButton.icon(
      onPressed: onNext,
      icon: Icon(
        filter == 'upcoming' || filter == 'completed'
            ? Icons.history
            : Icons.upcoming_outlined,
      ),
      label: Text(
        filter == 'upcoming' || filter == 'completed'
            ? 'View history'
            : 'View upcoming',
      ),
    ),
  );
}
