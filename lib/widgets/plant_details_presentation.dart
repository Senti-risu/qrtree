import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_layout.dart';

/// One route for named links, plant lists, inspection queues, and scanners.
/// Keeping the route non-opaque preserves the previous page behind web details.
Route<T> plantDetailsRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool platformIsWeb = kIsWeb,
}) {
  if (!platformIsWeb) {
    return MaterialPageRoute<T>(settings: settings, builder: builder);
  }
  return PageRouteBuilder<T>(
    settings: settings,
    opaque: false,
    barrierColor: Colors.black54,
    barrierDismissible: false,
    pageBuilder: (context, animation, secondaryAnimation) =>
        PlantDetailsPresentation(
          platformIsWeb: platformIsWeb,
          child: builder(context),
        ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
  );
}

class PlantDetailsPresentation extends StatelessWidget {
  const PlantDetailsPresentation({
    super.key,
    required this.child,
    this.platformIsWeb = kIsWeb,
  });
  final Widget child;
  final bool platformIsWeb;

  static bool floatsFor(Size size, {bool platformIsWeb = kIsWeb}) =>
      platformIsWeb &&
      size.width >= AppBreakpoints.desktop &&
      size.height >= 480;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!floatsFor(media.size, platformIsWeb: platformIsWeb)) return child;
    final height = math
        .min(
          860.0,
          media.size.height -
              media.viewInsets.bottom -
              media.padding.vertical -
              48,
        )
        .clamp(200.0, 860.0)
        .toDouble();
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            insetPadding: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.extraLarge,
            ),
            child: SizedBox(
              key: const ValueKey('floating-plant-details'),
              width: 1080,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
