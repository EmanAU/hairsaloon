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
  List<EmployeeItem>? employees,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in ids) {
    final id = raw.trim();
    if (id.isEmpty || id == selfId || seen.contains(id)) continue;
    if (knownIds != null && !knownIds.contains(id)) continue;
    if (employees != null &&
        wouldCreateAssignmentCycle(
          employeeId: selfId,
          targetId: id,
          employees: employees,
        )) {
      continue;
    }
    seen.add(id);
    result.add(id);
  }
  return result;
}

/// True when assigning [employeeId] → [targetId] would reverse hierarchy or
/// create a cycle (i.e. [employeeId] is already above [targetId]).
///
/// Example: if Ali is assigned to Bilal, Bilal cannot be assigned to Ali.
bool wouldCreateAssignmentCycle({
  required String employeeId,
  required String targetId,
  required List<EmployeeItem> employees,
}) {
  if (employeeId.isEmpty || targetId.isEmpty) return false;
  if (employeeId == targetId) return true;

  final byId = <String, EmployeeItem>{
    for (final employee in employees) employee.id: employee,
  };
  final seen = <String>{};
  var frontier = <String>[targetId];

  while (frontier.isNotEmpty) {
    final next = <String>[];
    for (final id in frontier) {
      final person = byId[id];
      if (person == null) continue;
      for (final managerId in person.assignedToIds) {
        if (managerId == employeeId) return true;
        if (seen.add(managerId)) next.add(managerId);
      }
    }
    frontier = next;
  }
  return false;
}
