import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'app_surface_group.dart';

/// Standard header -> tools -> results layout for staff workspace pages.
/// Results keep their own scrolling; short windows can scroll the tools away.
class AppWorkspacePage extends StatelessWidget {
  const AppWorkspacePage({
    super.key,
    this.header,
    this.tools,
    required this.body,
  });
  final Widget? header, tools;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sections = <Widget>[
        if (header != null && tools != null) ...[
          AppWorkspaceHeader(header: header!, tools: tools!),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          if (header != null) ...[
            header!,
            const SizedBox(height: AppSpacing.lg),
          ],
          if (tools != null) ...[tools!, const SizedBox(height: AppSpacing.lg)],
        ],
      ];
      final short =
          constraints.maxHeight < 440 ||
          MediaQuery.textScalerOf(context).scale(1) >= 1.4;
      if (short) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              SizedBox(height: 400, child: body),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sections,
          Expanded(child: body),
        ],
      );
    },
  );
}

class AppWorkspaceHeader extends StatelessWidget {
  const AppWorkspaceHeader({
    super.key,
    required this.header,
    required this.tools,
  });
  final Widget header, tools;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const ValueKey('workspace-heading-filters'),
    width: double.infinity,
    boxShadow: const [],
    child: AppSurfaceGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          tools,
        ],
      ),
    ),
  );
}

/// Filters and task tools use the same inset on every workspace page.
class AppToolbarCard extends StatelessWidget {
  const AppToolbarCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppCard(
    mergeWithParent: true,
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: child,
  );
}

/// A table's surface ends with its last row, not at the bottom of the window.
class AppTablePanel extends StatelessWidget {
  const AppTablePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      boxShadow: const [],
      child: child,
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search_off_rounded,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.green),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
