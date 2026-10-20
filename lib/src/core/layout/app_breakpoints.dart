import 'package:flutter/widgets.dart';

/// Shared layout breakpoints for phone vs tablet (landscape on device).
class AppBreakpoints {
  AppBreakpoints._();

  /// Width at which tablet layouts begin (logical pixels).
  static const double tablet = 600;

  static bool isTabletWidth(double width) => width >= tablet;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tablet;
}
