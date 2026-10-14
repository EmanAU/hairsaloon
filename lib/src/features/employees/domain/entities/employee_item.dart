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
    this.photoBase64,
    this.speciality,
    this.employeeType,
    this.basicSalary,
    this.commission,
    this.agreementDescription,
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
  final String? photoBase64;
  final String? speciality;
  final String? employeeType;
  final String? basicSalary;
  final String? commission;
  final String? agreementDescription;

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
    String? photoBase64,
    bool clearPhoto = false,
    String? speciality,
    String? employeeType,
    String? basicSalary,
    String? commission,
    String? agreementDescription,
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
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      speciality: speciality ?? this.speciality,
      employeeType: employeeType ?? this.employeeType,
      basicSalary: basicSalary ?? this.basicSalary,
      commission: commission ?? this.commission,
      agreementDescription:
          agreementDescription ?? this.agreementDescription,
    );
  }
}
