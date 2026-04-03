class User {
  final int? id;
  final String email;
  final String name;
  final String role; // 'farmer', 'vet', 'agronomist', 'admin'
  final String? phone;
  final DateTime createdAt;

  User({
    this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
      phone: json['phone'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}