import 'dart:ui' as ui;
import 'package:flutter/services.dart';

List<DeviceOrientation> businessOrientations(double shortestSide) =>
    shortestSide >= 600
    ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
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
