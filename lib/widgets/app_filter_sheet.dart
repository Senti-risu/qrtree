import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

/// Keep the choices scrollable and the apply/reset controls reachable in a
/// short landscape viewport or with enlarged text.
class AppFilterSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final String applyLabel;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const AppFilterSheet({
    super.key,
    required this.title,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final reset = OutlinedButton(
                    onPressed: onReset,
                    child: const Text('Reset'),
                  );
                  final apply = FilledButton(
                    onPressed: onApply,
                    child: Text(applyLabel, textAlign: TextAlign.center),
                  );
                  if (constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        apply,
                        const SizedBox(height: AppSpacing.xs),
                        reset,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: reset),
                      const SizedBox(width: AppSpacing.sm),
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
