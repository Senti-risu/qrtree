import 'package:flutter/material.dart';

/// Header and toolbar cards can share one outer surface without nested borders.
class AppSurfaceGroup extends InheritedWidget {
  const AppSurfaceGroup({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSurfaceGroup>() != null;

  @override
  bool updateShouldNotify(AppSurfaceGroup oldWidget) => false;
}
