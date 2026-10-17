import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

/// Standard header -> tools -> results layout for staff workspace pages.
/// Results keep their own scrolling; short windows can scroll the tools away.
class AppWorkspacePage extends StatelessWidget {
  const AppWorkspacePage({super.key, this.header, this.tools, required this.body});
  final Widget? header, tools;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final sections = <Widget>[
      if (header != null) ...[header!, const SizedBox(height: AppSpacing.lg)],
      if (tools != null) ...[tools!, const SizedBox(height: AppSpacing.lg)],
    ];
    final short = constraints.maxHeight < 440 ||
        (MediaQuery.textScalerOf(context).scale(1) >= 1.6 && constraints.maxHeight < 700);
    if (short) {
      return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...sections, SizedBox(height: 400, child: body)]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...sections, Expanded(child: body)]);
  });
}

/// Filters and task tools use the same inset on every workspace page.
class AppToolbarCard extends StatelessWidget {
  const AppToolbarCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppCard(width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg), child: child);
}
