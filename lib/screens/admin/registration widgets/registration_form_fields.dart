import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';

class RegistrationDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const RegistrationDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validValue = value != null && items.contains(value) ? value : null;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              key: ValueKey('$label-$validValue-${items.length}'),
              width: constraints.maxWidth,
              initialSelection: validValue,
              hintText: 'Type or select',
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              menuHeight: 280,
              trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              selectedTrailingIcon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.primary,
              ),
              dropdownMenuEntries: items
                  .map(
                    (item) =>
                        DropdownMenuEntry<String>(value: item, label: item),
                  )
                  .toList(),
              onSelected: onChanged,
              inputDecorationTheme: theme.inputDecorationTheme,
            );
          },
        ),
      ],
    );
  }
}

class RegistrationTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool readOnly;

  const RegistrationTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            fillColor: readOnly ? AppColors.surfaceVariant : null,
          ),
        ),
      ],
    );
  }
}

class RegistrationDateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;

  const RegistrationDateField({
    super.key,
    required this.value,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Planted',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value == null ? 'Select date' : _formatDate(value!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ResponsiveFieldPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const ResponsiveFieldPair({
    super.key,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.phone) {
          return Column(
            children: [
              first,
              const SizedBox(height: AppSpacing.lg),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
