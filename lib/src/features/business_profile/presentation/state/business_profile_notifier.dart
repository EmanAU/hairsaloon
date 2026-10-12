import 'package:flutter/foundation.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/clear_business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/get_business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/save_business_profile.dart';

class BusinessProfileNotifier extends ChangeNotifier {
  BusinessProfileNotifier({
    required GetBusinessProfile getBusinessProfile,
    required SaveBusinessProfile saveBusinessProfile,
    required ClearBusinessProfile clearBusinessProfile,
  }) : _getBusinessProfile = getBusinessProfile,
       _saveBusinessProfile = saveBusinessProfile,
       _clearBusinessProfile = clearBusinessProfile;

  final GetBusinessProfile _getBusinessProfile;
  final SaveBusinessProfile _saveBusinessProfile;
  final ClearBusinessProfile _clearBusinessProfile;

  BusinessProfile? _profile;
  BusinessProfile? get profile => _profile;

  Future<void> load() async {
    _profile = await _getBusinessProfile();
    notifyListeners();
  }

  Future<void> save(BusinessProfile profile) async {
    await _saveBusinessProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  Future<void> clear() async {
    await _clearBusinessProfile();
    _profile = null;
    notifyListeners();
  }
}
