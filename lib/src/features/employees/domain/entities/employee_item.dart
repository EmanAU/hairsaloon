class EmployeeItem {
  const EmployeeItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.cnicNumber,
    required this.homeAddress,
    required this.isActive,
    this.isManager = false,
    this.onlineSynced = false,
    this.photoBase64,
    this.speciality,
    this.employeeType,
    this.basicSalary,
    this.commission,
    this.agreementDescription,
    this.email = '',
    this.dateOfBirth,
    this.workStartedOn,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String cnicNumber;
  final String homeAddress;
  final bool isActive;

  /// Shop manager role. At most one employee should be manager at a time.
  /// A manager can still work as a normal employee.
  final bool isManager;

  /// Linked to this person's online profile, rather than a local-only contact.
  final bool onlineSynced;
  final String? photoBase64;
  final String? speciality;
  final String? employeeType;
  final String? basicSalary;
  final String? commission;
  final String? agreementDescription;
  final String email;
  final DateTime? dateOfBirth;
  final DateTime? workStartedOn;
  Map<String, dynamic> get onboardingData => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': phoneNumber,
    'cnicNumber': cnicNumber,
    'homeAddress': homeAddress,
    'isActive': isActive,
    'photoBase64': photoBase64,
    'speciality': speciality,
    'employeeType': employeeType,
    'dateOfBirth': dateOfBirth?.toIso8601String().substring(0, 10),
    'workStartedOn': workStartedOn?.toIso8601String().substring(0, 10),
  };

  String get fullName => '$firstName $lastName'.trim();

  EmployeeItem copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? cnicNumber,
    String? homeAddress,
    bool? isActive,
    bool? isManager,
    bool? onlineSynced,
    String? photoBase64,
    bool clearPhoto = false,
    String? speciality,
    String? employeeType,
    String? basicSalary,
    String? commission,
    String? agreementDescription,
    String? email,
    DateTime? dateOfBirth,
    DateTime? workStartedOn,
  }) {
    return EmployeeItem(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      homeAddress: homeAddress ?? this.homeAddress,
      isActive: isActive ?? this.isActive,
      isManager: isManager ?? this.isManager,
      onlineSynced: onlineSynced ?? this.onlineSynced,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      speciality: speciality ?? this.speciality,
      employeeType: employeeType ?? this.employeeType,
      basicSalary: basicSalary ?? this.basicSalary,
      commission: commission ?? this.commission,
      agreementDescription: agreementDescription ?? this.agreementDescription,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      workStartedOn: workStartedOn ?? this.workStartedOn,
    );
  }
}
