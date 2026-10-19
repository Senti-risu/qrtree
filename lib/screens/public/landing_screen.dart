import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';

/// Public introduction to CSU EcoTag.
///
/// This screen intentionally does not depend on an application session. The
/// only entry point leads to the access-choice screen at `/login`.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const String _backgroundAsset =
      'assets/images/ecotag-campus-trees.png';

  void _openAccessChoice(BuildContext context) {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.15, 0),
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: AppColors.darkGreen),
            ),
          ),
          const ExcludeSemantics(child: _ForestOverlay()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = AppBreakpoints.isPhone(constraints.maxWidth);
                final horizontalPadding = compact ? 20.0 : 48.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: compact ? 18 : 26,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (compact ? 36 : 52),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LandingHeader(
                              compact: compact,
                              onLogin: () => _openAccessChoice(context),
                            ),
                            SizedBox(height: compact ? 74 : 112),
                            _HeroContent(
                              compact: compact,
                              onLogin: () => _openAccessChoice(context),
                            ),
                            SizedBox(height: compact ? 64 : 96),
                            const _FeatureList(),
                            SizedBox(height: compact ? 42 : 62),
                            const Text(
                              'Cagayan State University  •  Campus Plant Profiling and Monitoring',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.heroMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ForestOverlay extends StatelessWidget {
  const _ForestOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkGreen.withValues(alpha: 0.96),
            AppColors.darkGreen.withValues(alpha: 0.78),
            AppColors.heroOverlay.withValues(alpha: 0.88),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.compact, required this.onLogin});

  final bool compact;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    if (compact && largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.green,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'EcoTag',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded, size: 19),
            label: const Text('Log In'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Colors.white, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: compact ? 46 : 52,
          height: compact ? 46 : 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 13 : 15),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.green,
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EcoTag',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                const Text(
                  'Cagayan State University',
                  style: TextStyle(
                    color: AppColors.heroMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login_rounded, size: 19),
          label: Text(compact ? 'Log In' : 'Log In To EcoTag'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
            side: const BorderSide(color: Colors.white, width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.compact, required this.onLogin});

  final bool compact;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 42 : 64,
      fontWeight: FontWeight.w900,
      height: 1.02,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
              ),
              child: const Text(
                'CAGAYAN STATE UNIVERSITY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Semantics(
              header: true,
              child: Text(
                'Know every tree.\nCare for every campus.',
                style: titleStyle,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'EcoTag is CSU’s QR-powered plant profiling and monitoring '
              'system. Discover campus plants, view verified profiles, and '
              'support timely care and conservation.',
              style: TextStyle(
                color: AppColors.heroSurface,
                fontSize: 18,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.arrow_forward_rounded, size: 21),
              label: Text(compact ? 'Continue' : 'Log In Or Continue As Guest'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkGreen,
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = !AppBreakpoints.isDesktop(constraints.maxWidth);
        const features = [
          _FeatureData(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan',
            description: 'Connect each QR tag to its verified plant profile.',
          ),
          _FeatureData(
            icon: Icons.local_florist_rounded,
            title: 'Learn',
            description: 'Explore plant identity, growth, and health details.',
          ),
          _FeatureData(
            icon: Icons.volunteer_activism_rounded,
            title: 'Protect',
            description: 'Support consistent monitoring and timely care.',
          ),
        ];

        if (stacked) {
          return Column(
            children: [
              for (var index = 0; index < features.length; index++) ...[
                _FeatureCard(data: features[index]),
                if (index != features.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < features.length; index++) ...[
                Expanded(child: _FeatureCard(data: features[index])),
                if (index != features.length - 1) const SizedBox(width: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.heroOverlayStrong.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.description,
                  style: const TextStyle(
                    color: AppColors.heroMuted,
                    fontSize: 13,
                    height: 1.4,
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

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
