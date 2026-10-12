import 'dart:convert';

import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';

class BusinessProfileModel {
  const BusinessProfileModel({
    required this.businessName,
    required this.phoneNumber,
    required this.businessType,
    required this.city,
    required this.area,
    required this.address,
  });

  factory BusinessProfileModel.fromEntity(BusinessProfile entity) {
    return BusinessProfileModel(
      businessName: entity.businessName,
      phoneNumber: entity.phoneNumber,
      businessType: entity.businessType,
      city: entity.city,
      area: entity.area,
      address: entity.address,
    );
  }

  factory BusinessProfileModel.fromJsonMap(Map<String, dynamic> json) {
    return BusinessProfileModel(
      businessName: (json['businessName'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      businessType: (json['businessType'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      area: (json['area'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
    );
  }

  factory BusinessProfileModel.fromJsonString(String raw) {
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Invalid business profile JSON.');
    }
    return BusinessProfileModel.fromJsonMap(map);
  }

  final String businessName;
  final String phoneNumber;
  final String businessType;
  final String city;
  final String area;
  final String address;

  BusinessProfile toEntity() {
    return BusinessProfile(
      businessName: businessName,
      phoneNumber: phoneNumber,
      businessType: businessType,
      city: city,
      area: area,
      address: address,
    );
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'businessType': businessType,
      'city': city,
      'area': area,
      'address': address,
    };
  }

  String toJsonString() => jsonEncode(toJsonMap());
}
