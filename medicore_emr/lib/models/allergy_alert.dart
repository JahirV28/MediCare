import 'dart:convert';

class AllergyAlert {
  final int? id;
  final int patientId;
  final String allergen;
  final String reaction;
  final String severity;
  final DateTime? documentedDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AllergyAlert({
    this.id,
    required this.patientId,
    required this.allergen,
    required this.reaction,
    this.severity = 'Leve',
    this.documentedDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'allergen': allergen,
      'reaction': reaction,
      'severity': severity,
      'documented_date': documentedDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AllergyAlert.fromMap(Map<String, dynamic> map) {
    return AllergyAlert(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      allergen: map['allergen'] as String,
      reaction: map['reaction'] as String,
      severity: map['severity'] as String? ?? 'Leve',
      documentedDate: map['documented_date'] != null ? DateTime.parse(map['documented_date']) : null,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory AllergyAlert.fromJson(String source) => AllergyAlert.fromMap(json.decode(source));
}
