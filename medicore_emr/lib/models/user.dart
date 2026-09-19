import 'dart:convert';

class User {
  final int? id;
  final String fullName;
  final String email;
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
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      providerId: map['provider_id'] as String?,
      passwordHash: map['password_hash'] as String?,
      roleId: map['role_id'] as int,
      roleName: map['role_name'] as String?,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) => User.fromMap(json.decode(source));

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }

  User copyWith({
    int? id,
    String? fullName,
    String? email,
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
