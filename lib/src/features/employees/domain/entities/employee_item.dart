class EmployeeItem {
  const EmployeeItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.cnicNumber,
    required this.homeAddress,
    required this.isActive,
    this.role = EmployeeRole.employee,
    this.managerId,
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
  final EmployeeRole role;
  /// Manager this employee reports to (null for managers / unassigned).
  final String? managerId;
  final String? photoBase64;
  final String? speciality;
  final String? employeeType;
  final String? basicSalary;
  final String? commission;
  final String? agreementDescription;

  String get fullName => '$firstName $lastName'.trim();
  bool get isManager => role == EmployeeRole.manager;

  EmployeeItem copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? cnicNumber,
    String? homeAddress,
    bool? isActive,
    EmployeeRole? role,
    String? managerId,
    bool clearManagerId = false,
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
      role: role ?? this.role,
      managerId: clearManagerId ? null : (managerId ?? this.managerId),
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

enum EmployeeRole {
  employee,
  manager;

  static EmployeeRole fromStorage(String? value) {
    if (value == EmployeeRole.manager.name) return EmployeeRole.manager;
    return EmployeeRole.employee;
  }
}
