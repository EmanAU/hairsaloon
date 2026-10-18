enum AppAudience { business, customer }

class OnlineFailure implements Exception {
  const OnlineFailure(this.message);
  final String message;
}

class SalonStaff {
  const SalonStaff({
    required this.id,
    required this.name,
    required this.isWorking,
  });
  final String id;
  final String name;
  final bool isWorking;
  factory SalonStaff.fromJson(Map<String, dynamic> json) => SalonStaff(
    id: json['membership_id'] as String,
    name: json['display_name'] as String,
    isWorking: json['is_working'] as bool,
  );
}

class WorkContract {
  const WorkContract({
    required this.id,
    required this.employeeId,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.salary,
    required this.commission,
    required this.terms,
    this.businessName = 'Salon unavailable',
    this.releaseReason,
  });
  final String id;
  final String employeeId;
  final String kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String status;
  final double salary;
  final double commission;
  final String terms;
  final String businessName;
  final String? releaseReason;

  bool get canRelease =>
      status == 'accepted' &&
      (endsAt == null || endsAt!.isAfter(DateTime.now()));
  bool get endingSoon =>
      canRelease &&
      endsAt != null &&
      endsAt!.difference(DateTime.now()) <= const Duration(days: 7);
  String get displayStatus {
    if (status != 'accepted') return status;
    if (endsAt != null && !endsAt!.isAfter(DateTime.now())) return 'expired';
    return startsAt.isAfter(DateTime.now()) ? 'scheduled' : 'active';
  }

  factory WorkContract.fromJson(Map<String, dynamic> json) => WorkContract(
    id: json['id'] as String,
    employeeId: json['employee_id'] as String,
    kind: json['kind'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
    status: json['status'] as String,
    salary: (json['salary'] as num).toDouble(),
    commission: (json['commission_percent'] as num).toDouble(),
    terms: json['terms'] as String,
    businessName:
        ((json['business_employees'] as Map?)?['businesses'] as Map?)?['name']
            as String? ??
        'Salon unavailable',
    releaseReason: json['release_reason'] as String?,
  );
}

class OnlineAccount {
  const OnlineAccount({required this.id, required this.name});
  final String id;
  final String name;
}

class PersonalProfile {
  const PersonalProfile({
    required this.code,
    required this.phone,
    this.cnic,
    this.dateOfBirth,
    this.workStartedOn,
    this.photoPath,
  });
  final String code;
  final String phone;
  final String? cnic;
  final DateTime? dateOfBirth;
  final DateTime? workStartedOn;
  final String? photoPath;

  bool get isComplete =>
      phone.isNotEmpty &&
      (cnic?.length == 13) &&
      dateOfBirth != null &&
      workStartedOn != null &&
      (photoPath?.isNotEmpty ?? false);

  String experienceAt(DateTime today) {
    final start = workStartedOn;
    if (start == null || start.isAfter(today)) return 'Not set';
    var months = (today.year - start.year) * 12 + today.month - start.month;
    if (today.day < start.day) months--;
    if (months <= 0) return 'Less than a month';
    final years = months ~/ 12;
    final remaining = months % 12;
    return [
      if (years > 0) '$years ${years == 1 ? 'year' : 'years'}',
      if (remaining > 0) '$remaining ${remaining == 1 ? 'month' : 'months'}',
    ].join(' ');
  }

  factory PersonalProfile.fromJson(Map<String, dynamic> json) =>
      PersonalProfile(
        code: json['code'] as String,
        phone: json['phone'] as String,
        cnic: json['cnic'] as String?,
        dateOfBirth: DateTime.tryParse(json['date_of_birth'] as String? ?? ''),
        workStartedOn: DateTime.tryParse(
          json['work_started_on'] as String? ?? '',
        ),
        photoPath: json['photo_path'] as String?,
      );
}

class SalonBusiness {
  const SalonBusiness({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.city,
    required this.area,
    required this.address,
    required this.isActive,
    this.logoPath,
  });
  final String id;
  final String name;
  final String phone;
  final String type;
  final String city;
  final String area;
  final String address;
  final bool isActive;
  final String? logoPath;

  factory SalonBusiness.fromJson(Map<String, dynamic> json) => SalonBusiness(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    type: json['business_type'] as String,
    city: json['city'] as String,
    area: json['area'] as String,
    address: json['address'] as String,
    isActive: json['is_active'] as bool,
    logoPath: json['logo_path'] as String?,
  );
}

class OnlineWorkspace {
  const OnlineWorkspace({
    required this.account,
    this.profile,
    this.businesses = const [],
    this.isCached = false,
  });
  final OnlineAccount account;
  final PersonalProfile? profile;
  final List<SalonBusiness> businesses;
  final bool isCached;
}

class SalonService {
  const SalonService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isActive;

  factory SalonService.fromJson(Map<String, dynamic> json) => SalonService(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    price: (json['price'] as num).toDouble(),
    category: json['category'] as String,
    isActive: json['is_active'] as bool,
  );
}
