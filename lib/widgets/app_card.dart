import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_surface_group.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final Color color;
  final BorderRadiusGeometry borderRadius;
  final BoxBorder border;
  final List<BoxShadow> boxShadow;
  final Clip clipBehavior;
  final bool mergeWithParent;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.margin,
    this.alignment,
    this.color = AppColors.surface,
    this.borderRadius = const BorderRadius.all(Radius.circular(13)),
    this.border = AppBorders.subtle,
    this.boxShadow = AppShadows.card,
    this.clipBehavior = Clip.none,
    this.mergeWithParent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mergeWithParent && AppSurfaceGroup.contains(context)) {
      return SizedBox(width: width, height: height, child: child);
    }
    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      padding:
          padding ??
          EdgeInsets.all(
            AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width)
                ? AppSpacing.lg
                : AppSpacing.xl,
          ),
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
