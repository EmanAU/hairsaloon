import 'package:flutter/material.dart';

/// Keeps forms readable on tablets while allowing workspace pages more room.
/// Also clears the Android system navigation bar so content is never hidden.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({super.key, required this.child, this.form = false});

  final Widget child;
  final bool form;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    // Keep body / buttons above the system gesture / 3-button nav bar.
    final safeChild = SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: child,
    );

    if (!isTablet(context)) return safeChild;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: form ? 560 : 1200),
          child: SizedBox.expand(child: safeChild),
        ),
      ),
    );
  }
}
