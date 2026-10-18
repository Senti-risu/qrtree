import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        child: Image.asset(
          'assets/images/ecotag-campus-trees.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0.15, 0),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stackTrace) =>
              const ColoredBox(color: AppColors.darkGreen),
        ),
      ),
      ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.darkGreen.withValues(alpha: 0.64),
                AppColors.heroOverlayDark.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ),
      SafeArea(child: child),
    ],
  );
}
