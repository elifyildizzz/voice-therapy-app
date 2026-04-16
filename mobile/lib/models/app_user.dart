class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    this.passwordHash = '',
  });

  factory AppUser.fromDatabase(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      passwordHash: map['password_hash'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  factory AppUser.fromApi(Map<String, dynamic> map) {
    final createdAtValue = map['created_at'] ?? map['createdAt'];
    return AppUser(
      id: map['id'].toString(),
      email: map['email'] as String,
      firstName: (map['first_name'] ?? map['firstName']) as String,
      lastName: (map['last_name'] ?? map['lastName']) as String,
      createdAt: createdAtValue is String
          ? DateTime.parse(createdAtValue).toLocal()
          : DateTime.now(),
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String passwordHash;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password_hash': passwordHash,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
