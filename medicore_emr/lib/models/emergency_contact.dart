import 'dart:convert';

class EmergencyContact {
  final int? id;
  final int? patientId;
  final String contactName;
  final String relationship;
  final String phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmergencyContact({
    this.id,
    this.patientId,
    required this.contactName,
    required this.relationship,
    required this.phone,
    this.createdAt,
    this.updatedAt,
  });

  EmergencyContact copyWith({
    int? id,
    int? patientId,
    String? contactName,
    String? relationship,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      contactName: contactName ?? this.contactName,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'contact_name': contactName,
      'relationship': relationship,
      'phone': phone,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int?,
      contactName: map['contact_name'] as String,
      relationship: map['relationship'] as String,
      phone: map['phone'] as String,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(String source) => EmergencyContact.fromMap(json.decode(source));
}
