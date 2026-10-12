import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/business_profile/data/models/business_profile_model.dart';
import 'package:hairsaloon/src/features/business_profile/data/repositories/shared_prefs_business_profile_repository.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';

void main() {
  test('business logo survives saving and reloading local profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final logo = base64Encode([1, 2, 3, 4]);
    await SharedPrefsBusinessProfileRepository(prefs: prefs).saveProfile(
      BusinessProfile(
        businessName: 'Salon',
        phoneNumber: '+923001234567',
        businessType: 'Hair Salon',
        city: 'Islamabad',
        area: 'G-11',
        address: 'G-11 Markaz',
        logoBase64: logo,
      ),
    );
    final restored = await SharedPrefsBusinessProfileRepository(
      prefs: prefs,
    ).getProfile();
    expect(restored?.logoBase64, logo);
    expect(restored?.businessName, 'Salon');
  });

  test('existing profiles without a logo remain readable', () {
    final profile = BusinessProfileModel.fromJsonMap({
      'businessName': 'Old Salon',
    }).toEntity();
    expect(profile.businessName, 'Old Salon');
    expect(profile.logoBase64, isNull);
  });
}
