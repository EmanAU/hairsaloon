import 'package:flutter/material.dart';

/// Scroll/content padding that clears the Android system navigation bar.
class SafeScrollPadding {
  const SafeScrollPadding._();

  static EdgeInsets of(
    BuildContext context, {
    double left = 16,
    double top = 16,
    double right = 16,
    double bottom = 16,
  }) {
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + systemBottom,
    );
  }
}
