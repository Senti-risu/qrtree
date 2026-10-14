import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';

/// Lets a visitor choose the correct EcoTag access path before credentials or
/// guest information are requested.
class AccessChoiceScreen extends StatelessWidget {
  const AccessChoiceScreen({super.key});

  static const String _backgroundAsset =
      'assets/images/ecotag-campus-trees.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            if (AppBreakpoints.isDesktop(constraints.maxWidth) &&
                textScale < 1.3) {
              return Row(
                children: [
                  const Expanded(flex: 5, child: _DesktopBrandPanel()),
                  Expanded(
                    flex: 6,
                    child: _ChoicePanel(
                      onBack: () => _returnHome(context),
                      onStaff: () => _open(context, '/staff-login'),
                      onGuest: () => _open(context, '/guest-entry'),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _MobileBrandBanner(),
                      const SizedBox(height: 16),
                      _ChoicePanel(
                        embedded: true,
                        onBack: () => _returnHome(context),
                        onStaff: () => _open(context, '/staff-login'),
                        onGuest: () => _open(context, '/guest-entry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _open(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  void _returnHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: Image.asset(
            AccessChoiceScreen._backgroundAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(0.1, 0),
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.darkGreen),
          ),
        ),
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.darkGreen.withValues(alpha: 0.76),
                  AppColors.heroOverlayDark.withValues(alpha: 0.94),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(light: true),
              const Spacer(),
              const Text(
                'One system for a\ngreener CSU.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose the access option that matches how you use EcoTag.',
                style: TextStyle(
                  color: AppColors.heroMutedAlt,
                  fontSize: 17,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Text(
                  'CAGAYAN STATE UNIVERSITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileBrandBanner extends StatelessWidget {
  const _MobileBrandBanner();

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final bannerHeight = 156.0 + ((textScale - 1).clamp(0, 1) * 72.0);
    return Container(
      height: bannerHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              AccessChoiceScreen._backgroundAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.1, 0),
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: AppColors.darkGreen),
            ),
          ),
          ExcludeSemantics(
            child: ColoredBox(
              color: AppColors.darkGreen.withValues(alpha: 0.82),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BrandMark(light: true),
                Text(
                  'Campus plants, connected and cared for.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.onBack,
    required this.onStaff,
    required this.onGuest,
    this.embedded = false,
  });

  final VoidCallback onBack;
  final VoidCallback onStaff;
  final VoidCallback onGuest;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 19),
                label: const Text('Back to EcoTag home'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How would you like to continue?',
            style: TextStyle(
              color: AppColors.darkGreen,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose the option that best describes you. You can return here at any time.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final sideBySide =
                  !AppBreakpoints.isPhone(constraints.maxWidth) &&
                  textScale < 1.3;
              final staff = FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: _AccessCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin & Inspection Team',
                  description:
                      'Use your assigned CSU EcoTag username and password.',
                  supportingText:
                      'For Super, University, Campus, and College Admins, plus Inspection Teams.',
                  actionLabel: 'Staff sign in',
                  color: AppColors.green,
                  backgroundColor: AppColors.primaryContainer,
                  onTap: onStaff,
                ),
              );
              final guest = FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: _AccessCard(
                  icon: Icons.public_rounded,
                  title: 'Guest',
                  description:
                      'Explore public plant information without a staff account.',
                  supportingText:
                      'You will be asked for an optional name and your age for visitor statistics.',
                  actionLabel: 'Continue as guest',
                  color: AppColors.secondary,
                  backgroundColor: AppColors.secondaryContainer,
                  onTap: onGuest,
                ),
              );

              if (sideBySide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: staff),
                      const SizedBox(width: 14),
                      Expanded(child: guest),
                    ],
                  ),
                );
              }

              return Column(
                children: [staff, const SizedBox(height: 14), guest],
              );
            },
          ),
          const SizedBox(height: 22),
          const _SecurityNote(),
        ],
      ),
    );

    if (embedded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(22), child: content),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: content,
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.supportingText,
    required this.actionLabel,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String supportingText;
  final String actionLabel;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = '$title. $description $supportingText $actionLabel';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.34), width: 1.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            focusColor: color.withValues(alpha: 0.12),
            hoverColor: color.withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    supportingText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: color, size: 21),
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
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.green, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Staff permissions are assigned by CSU and verified securely after sign-in.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.light});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.darkGreen;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: light ? Colors.white : AppColors.green,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.eco_rounded,
            color: light ? AppColors.green : Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EcoTag',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cagayan State University',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: light ? AppColors.heroMuted : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
