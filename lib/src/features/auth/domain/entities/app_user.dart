class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String username;
  final String phone;
  final DateTime createdAt;
}
