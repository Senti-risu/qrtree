import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

/// A wrapping step indicator: no fixed-height labels or tiny tap targets.
class RegistrationProgress extends StatelessWidget {
  static const labels = ['Plant', 'Location', 'Photo', 'Review'];
  final int currentStep;
  final ValueChanged<int>? onStepSelected;

  const RegistrationProgress({
    super.key,
    required this.currentStep,
    this.onStepSelected,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'Step ${currentStep + 1} of 4 · ${labels[currentStep]}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 2
                : 4;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (var index = 0; index < labels.length; index++)
                  SizedBox(
                    width:
                        (constraints.maxWidth - AppSpacing.xs * (columns - 1)) /
                        columns,
                    child: Semantics(
                      selected: index == currentStep,
                      child: TextButton(
                        onPressed: index < currentStep && onStepSelected != null
                            ? () => onStepSelected!(index)
                            : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: index == currentStep
                              ? AppColors.primaryContainer
                              : Colors.transparent,
                          disabledForegroundColor: index == currentStep
                              ? AppColors.darkGreen
                              : AppColors.textSecondary,
                        ),
                        child: Text(
                          '${index < currentStep ? '✓' : index + 1} ${labels[index]}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
