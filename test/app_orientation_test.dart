import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/layout/app_orientation.dart';

void main() {
  test('phones stay portrait; tablets lock to landscape', () {
    expect(businessOrientations(390), [DeviceOrientation.portraitUp]);
    expect(businessOrientations(599), [DeviceOrientation.portraitUp]);
    expect(businessOrientations(600), [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    expect(businessOrientations(800), [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  });
}
