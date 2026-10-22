import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Opens a filter sheet with the same shape and behaviour on every screen.
Future<T?> showAppFilterSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: builder,
);

/// A labelled group of filter choices inside [AppFilterSheet].
class AppFilterSection extends StatelessWidget {
  final String label;
  final Widget child;

  const AppFilterSection({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.darkGreen,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      child,
    ],
  );
}

/// Wraps [AppFilterSection]s with equal spacing between them.
class AppFilterSections extends StatelessWidget {
  final List<Widget> sections;

  const AppFilterSections({super.key, required this.sections});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.xl),
        sections[i],
      ],
    ],
  );
}

/// The standard selectable chip used inside filter sheets.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final Color accent;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.accent = AppColors.green,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    showCheckmark: false,
    avatar: icon == null
        ? null
        : Icon(
            icon,
            size: 18,
            color: selected ? accent : AppColors.textSecondary,
          ),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    selectedColor: accent.withValues(alpha: .11),
    backgroundColor: AppColors.surface,
    side: BorderSide(
      color: selected ? accent : AppColors.border,
      width: selected ? 1.3 : 1,
    ),
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
    labelStyle: TextStyle(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: selected ? AppColors.darkGreen : AppColors.textPrimary,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Keep the choices scrollable and the apply/reset controls reachable in a
/// short landscape viewport or with enlarged text.
class AppFilterSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final String applyLabel;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const AppFilterSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.applyLabel,
    required this.onReset,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadii.medium,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: child,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final reset = OutlinedButton(
                    onPressed: onReset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.medium,
                      ),
                    ),
                    child: const Text('Reset'),
                  );
                  final apply = FilledButton(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.green,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.medium,
                      ),
                    ),
                    child: Text(applyLabel, textAlign: TextAlign.center),
                  );
                  if (constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        apply,
                        const SizedBox(height: AppSpacing.sm),
                        reset,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: reset),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 2, child: apply),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
