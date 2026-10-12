class CustomerContact {
  const CustomerContact({required this.name, required this.phone});

  final String name;
  final String phone;

  String get displayLabel {
    final n = name.trim();
    final p = phone.trim();
    if (n.isEmpty) return p;
    if (p.isEmpty) return n;
    return '$n • $p';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'phone': phone,
  };

  factory CustomerContact.fromJson(Map<String, dynamic> json) {
    return CustomerContact(
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }
}
