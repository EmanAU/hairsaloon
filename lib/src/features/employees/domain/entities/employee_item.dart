class EmployeeItem {
  const EmployeeItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.cnicNumber,
    required this.homeAddress,
    required this.isActive,
    this.assignedToIds = const <String>[],
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

  /// Other employees this person is assigned to. Never includes [id].
  final List<String> assignedToIds;
  final String? photoBase64;
  final String? speciality;
  final String? employeeType;
  final String? basicSalary;
  final String? commission;
  final String? agreementDescription;

  String get fullName => '$firstName $lastName'.trim();

  bool get isAssigned => assignedToIds.isNotEmpty;

  EmployeeItem copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? cnicNumber,
    String? homeAddress,
    bool? isActive,
    List<String>? assignedToIds,
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
      assignedToIds: assignedToIds ?? this.assignedToIds,
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

/// Unique ids, never [selfId], never empty strings.
List<String> sanitizeAssignedToIds({
  required String selfId,
  required Iterable<String> ids,
  Set<String>? knownIds,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in ids) {
    final id = raw.trim();
    if (id.isEmpty || id == selfId || seen.contains(id)) continue;
    if (knownIds != null && !knownIds.contains(id)) continue;
    seen.add(id);
    result.add(id);
  }
  return result;
}
