import 'dart:convert';

class PrescriptionItem {
  final int? id;
  final int? prescriptionId;
  final String drugName;
  final String dose;
  final String frequency;
  final String duration;
  final String? instructions;

  PrescriptionItem({
    this.id,
    this.prescriptionId,
    required this.drugName,
    required this.dose,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prescription_id': prescriptionId,
      'drug_name': drugName,
      'dose': dose,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) {
    return PrescriptionItem(
      id: map['id'] as int?,
      prescriptionId: map['prescription_id'] as int?,
      drugName: map['drug_name'] as String,
      dose: map['dose'] as String,
      frequency: map['frequency'] as String,
      duration: map['duration'] as String,
      instructions: map['instructions'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory PrescriptionItem.fromJson(String source) =>
      PrescriptionItem.fromMap(json.decode(source));

  PrescriptionItem copyWith({
    int? id,
    int? prescriptionId,
    String? drugName,
    String? dose,
    String? frequency,
    String? duration,
    String? instructions,
  }) {
    return PrescriptionItem(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      drugName: drugName ?? this.drugName,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      instructions: instructions ?? this.instructions,
    );
  }
}

class Prescription {
  final int? id;
  final int patientId;
  final String patientName;
  final String patientCode;
  final int? patientAge;
  final double? patientWeightKg;
  final String? patientAllergies;
  final String clinicName;
  final String clinicAddress;
  final String doctorName;
  final String professionalLicense;
  final DateTime date;
  final List<PrescriptionItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Prescription({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.patientCode,
    this.patientAge,
    this.patientWeightKg,
    this.patientAllergies,
    this.clinicName = 'Clínica Sanitas Central',
    this.clinicAddress = 'Av. Principal 123, Ciudad • Tel: 555-0192',
    this.doctorName = 'Dr. Carlos Mendoza',
    this.professionalLicense = 'C.M. 45892',
    required this.date,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient_name': patientName,
      'patient_code': patientCode,
      'patient_age': patientAge,
      'patient_weight_kg': patientWeightKg,
      'patient_allergies': patientAllergies,
      'clinic_name': clinicName,
      'clinic_address': clinicAddress,
      'doctor_name': doctorName,
      'professional_license': professionalLicense,
      'date': date.toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      patientName: map['patient_name'] as String,
      patientCode: map['patient_code'] as String,
      patientAge: map['patient_age'] as int?,
      patientWeightKg: (map['patient_weight_kg'] as num?)?.toDouble(),
      patientAllergies: map['patient_allergies'] as String?,
      clinicName: map['clinic_name'] as String? ?? 'Clínica Sanitas Central',
      clinicAddress: map['clinic_address'] as String? ?? 'Av. Principal 123, Ciudad • Tel: 555-0192',
      doctorName: map['doctor_name'] as String? ?? 'Dr. Carlos Mendoza',
      professionalLicense: map['professional_license'] as String? ?? 'C.M. 45892',
      date: DateTime.parse(map['date']),
      items: (map['items'] as List<dynamic>?)
              ?.map((x) => PrescriptionItem.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Prescription.fromJson(String source) =>
      Prescription.fromMap(json.decode(source));

  Prescription copyWith({
    int? id,
    int? patientId,
    String? patientName,
    String? patientCode,
    int? patientAge,
    double? patientWeightKg,
    String? patientAllergies,
    String? clinicName,
    String? clinicAddress,
    String? doctorName,
    String? professionalLicense,
    DateTime? date,
    List<PrescriptionItem>? items,
  }) {
    return Prescription(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientCode: patientCode ?? this.patientCode,
      patientAge: patientAge ?? this.patientAge,
      patientWeightKg: patientWeightKg ?? this.patientWeightKg,
      patientAllergies: patientAllergies ?? this.patientAllergies,
      clinicName: clinicName ?? this.clinicName,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      doctorName: doctorName ?? this.doctorName,
      professionalLicense: professionalLicense ?? this.professionalLicense,
      date: date ?? this.date,
      items: items ?? this.items,
    );
  }
}
