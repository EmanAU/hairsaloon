import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'app_breakpoints.dart';

/// Business app: phones and tablets stay portrait (per responsive-layout rule).
List<DeviceOrientation> businessOrientations(double shortestSide) =>
    shortestSide >= AppBreakpoints.tablet
    ? const [DeviceOrientation.portraitUp]
    : const [DeviceOrientation.portraitUp];

Future<void> configureAppOrientation({bool business = true}) {
  final display = ui.PlatformDispatcher.instance.implicitView?.display;
  // Read the full display, so Android letterboxing cannot change device class.
  final shortestSide = display == null
      ? 0.0
      : display.size.shortestSide / display.devicePixelRatio;
  return SystemChrome.setPreferredOrientations(
    business
        ? businessOrientations(shortestSide)
        : const [DeviceOrientation.portraitUp],
  );
}
