import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'app_breakpoints.dart';

/// Phones stay portrait; tablets lock to landscape (matches POS + online shells).
List<DeviceOrientation> businessOrientations(double shortestSide) =>
    shortestSide >= AppBreakpoints.tablet
    ? const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]
    : const [DeviceOrientation.portraitUp];

Future<void> configureAppOrientation({bool business = true}) {
  final display = ui.PlatformDispatcher.instance.implicitView?.display;
  // Read the full display, so Android letterboxing cannot change device class.
  final shortestSide = display == null
      ? 0.0
      : display.size.shortestSide / display.devicePixelRatio;
  // Customer and business flavors share the same phone/tablet rotation rules.
  return SystemChrome.setPreferredOrientations(
    businessOrientations(shortestSide),
  );
}
