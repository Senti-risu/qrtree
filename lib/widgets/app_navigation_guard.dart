import 'package:flutter/material.dart';

/// Shared navigation controls must ask before replacing an unfinished form.
class AppNavigationGuard extends InheritedWidget {
  final Future<bool> Function() canLeave;

  const AppNavigationGuard({
    super.key,
    required this.canLeave,
    required super.child,
  });

  static Future<bool> confirm(BuildContext context) async =>
      await context
          .getInheritedWidgetOfExactType<AppNavigationGuard>()
          ?.canLeave() ??
      true;

  @override
  bool updateShouldNotify(AppNavigationGuard oldWidget) =>
      canLeave != oldWidget.canLeave;
}
