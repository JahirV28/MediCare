import 'dart:convert';

class Patient {
  final int? id;
  final String patientCode;
  final String fullName;
  final String? identityNumber;
  final DateTime? birthDate;
  final String? gender;
  final String? phone;
  final String? email;
  final String? address;
  final String? bloodType;
  final String? photoUrl;
  final bool isActive;
  final bool hasAlert;
  final DateTime? lastVisit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Patient({
    this.id,
    required this.patientCode,
    required this.fullName,
    this.identityNumber,
    this.birthDate,
    this.gender,
    this.phone,
    this.email,
    this.address,
    this.bloodType,
    this.photoUrl,
    this.isActive = true,
    this.hasAlert = false,
    this.lastVisit,
    this.createdAt,
    this.updatedAt,
  });

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int a = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      a--;
    }
    return a;
  }

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_code': patientCode,
      'full_name': fullName,
      'identity_number': identityNumber,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'phone': phone,
      'email': email,
      'address': address,
      'blood_type': bloodType,
      'photo_url': photoUrl,
      'is_active': isActive ? 1 : 0,
      'has_alert': hasAlert ? 1 : 0,
      'last_visit': lastVisit?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int?,
      patientCode: map['patient_code'] as String,
      fullName: map['full_name'] as String,
      identityNumber: map['identity_number'] as String?,
      birthDate: map['birth_date'] != null ? DateTime.parse(map['birth_date']) : null,
      gender: map['gender'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      bloodType: map['blood_type'] as String?,
      photoUrl: map['photo_url'] as String?,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      hasAlert: map['has_alert'] == 1 || map['has_alert'] == true,
      lastVisit: map['last_visit'] != null ? DateTime.parse(map['last_visit']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Patient.fromJson(String source) => Patient.fromMap(json.decode(source));

  Patient copyWith({
    int? id,
    String? patientCode,
    String? fullName,
    String? identityNumber,
    DateTime? birthDate,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? bloodType,
    String? photoUrl,
    bool? isActive,
    bool? hasAlert,
    DateTime? lastVisit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      patientCode: patientCode ?? this.patientCode,
      fullName: fullName ?? this.fullName,
      identityNumber: identityNumber ?? this.identityNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      bloodType: bloodType ?? this.bloodType,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      hasAlert: hasAlert ?? this.hasAlert,
      lastVisit: lastVisit ?? this.lastVisit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
