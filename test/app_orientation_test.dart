import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/layout/app_orientation.dart';

void main() {
  test('phones and tablets stay portrait for the business app', () {
    expect(businessOrientations(390), [DeviceOrientation.portraitUp]);
    expect(businessOrientations(599), [DeviceOrientation.portraitUp]);
    expect(businessOrientations(600), [DeviceOrientation.portraitUp]);
    expect(businessOrientations(800), [DeviceOrientation.portraitUp]);
  });
}
