import 'dart:convert';

class User {
  final int? id;
  final String fullName;
  final String email;
  final String? phone;
  final String? specialty;
  final String? licenseNumber;
  final String? providerId;
  final String? passwordHash;
  final int roleId;
  final String? roleName;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.specialty,
    this.licenseNumber,
    this.providerId,
    this.passwordHash,
    required this.roleId,
    this.roleName,
    this.isActive = true,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'specialty': specialty,
      'license_number': licenseNumber,
      'provider_id': providerId,
      'password_hash': passwordHash,
      'role_id': roleId,
      'role_name': roleName,
      'is_active': isActive ? 1 : 0,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      fullName: (map['full_name'] as String?) ?? 'Usuario',
      email: (map['email'] as String?) ?? '',
      phone: map['phone'] as String?,
      specialty: map['specialty'] as String?,
      licenseNumber: (map['license_number'] as String?) ?? (map['provider_id'] as String?),
      providerId: map['provider_id'] as String?,
      passwordHash: map['password_hash'] as String?,
      roleId: (map['role_id'] as num?)?.toInt() ?? 2,
      roleName: map['role_name'] as String?,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      lastLogin: map['last_login'] != null ? DateTime.tryParse(map['last_login'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) => User.fromMap(json.decode(source));

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (fullName.trim().isNotEmpty) {
      return fullName.trim().substring(0, fullName.trim().length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'DR';
  }

  User copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    String? specialty,
    String? licenseNumber,
    String? providerId,
    String? passwordHash,
    int? roleId,
    String? roleName,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      specialty: specialty ?? this.specialty,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      providerId: providerId ?? this.providerId,
      passwordHash: passwordHash ?? this.passwordHash,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
