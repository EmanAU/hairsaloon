import 'package:flutter/material.dart';

/// Keeps forms readable on tablets while allowing workspace pages more room.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({super.key, required this.child, this.form = false});

  final Widget child;
  final bool form;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    if (!isTablet(context)) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: form ? 560 : 1200),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
