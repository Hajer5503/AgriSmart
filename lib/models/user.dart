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
    final raw = json['created_at'];
    DateTime created;
    if (raw == null) {
      created = DateTime.now();
    } else if (raw is DateTime) {
      created = raw;
    } else {
      created = DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }
    final rawId = json['id'];
    int? id;
    if (rawId is int) {
      id = rawId;
    } else if (rawId is num) {
      id = rawId.toInt();
    }
    return User(
      id: id,
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'farmer',
      phone: json['phone']?.toString(),
      createdAt: created,
    );
  }
}