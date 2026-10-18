import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'widgets/auth_backdrop.dart';

class AccessChoiceScreen extends StatelessWidget {
  const AccessChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.3;
        if (wide) {
          return Row(
            children: [
              const Expanded(flex: 4, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: _ChoicePanel(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height:
                            210 +
                            150 *
                                (MediaQuery.textScalerOf(context).scale(1) - 1)
                                    .clamp(0, 2),
                        child: const _BrandPanel(compact: true),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ChoicePanel(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => AuthBackdrop(
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 24 : 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandLogo(),
              SizedBox(height: compact ? 24 : 40),
              Text(
                'One system for a\ngreener CSU.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 28 : 42,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.eco_rounded, color: AppColors.green, size: 28),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EcoTag',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Cagayan State University',
              style: TextStyle(color: AppColors.heroMutedAlt, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChoicePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 24 : 32),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: FocusTraversalGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to EcoTag home'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'How would you like to continue?',
            style: TextStyle(
              color: AppColors.darkGreen,
              fontSize: AppTypography.pageTitle,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final staff = _AccessCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin & Inspection Team',
                action: 'Staff sign in',
                color: AppColors.green,
                primary: true,
                onTap: () => Navigator.pushNamed(context, '/staff-login'),
              );
              final guest = _AccessCard(
                icon: Icons.public_rounded,
                title: 'Guest',
                action: 'Continue as guest',
                color: AppColors.secondary,
                onTap: () => Navigator.pushNamed(context, '/guest-entry'),
              );
              if (constraints.maxWidth >= 540 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.3) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: staff),
                      const SizedBox(width: 16),
                      Expanded(child: guest),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [staff, const SizedBox(height: 14), guest],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.action,
    required this.color,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title;
  final String action;
  final Color color;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $action',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: primary ? AppColors.primaryContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: primary ? 0.4 : 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.06),
          focusColor: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white
                        : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: color, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
