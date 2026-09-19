import 'dart:convert';

class ClinicalRecord {
  final int? id;
  final int patientId;
  final int doctorId;
  final String recordType;
  final String title;
  final String? description;
  final DateTime recordDate;
  final List<String>? tags;
  final String? doctorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClinicalRecord({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.recordType,
    required this.title,
    this.description,
    required this.recordDate,
    this.tags,
    this.doctorName,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'record_type': recordType,
      'title': title,
      'description': description,
      'record_date': recordDate.toIso8601String(),
      'tags': tags != null ? json.encode(tags) : null,
      'doctor_name': doctorName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ClinicalRecord.fromMap(Map<String, dynamic> map) {
    List<String>? parsedTags;
    if (map['tags'] != null) {
      if (map['tags'] is List) {
        parsedTags = List<String>.from(map['tags']);
      } else if (map['tags'] is String) {
        parsedTags = List<String>.from(json.decode(map['tags']));
      }
    }
    return ClinicalRecord(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int,
      recordType: map['record_type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      recordDate: DateTime.parse(map['record_date']),
      tags: parsedTags,
      doctorName: map['doctor_name'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ClinicalRecord.fromJson(String source) => ClinicalRecord.fromMap(json.decode(source));
}
