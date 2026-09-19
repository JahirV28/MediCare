import 'dart:convert';

class VitalSigns {
  final int? id;
  final int? consultationId;
  final int bpSystolic;
  final int bpDiastolic;
  final int pulse;
  final double temperature;
  final double weightKg;
  final double heightCm;

  VitalSigns({
    this.id,
    this.consultationId,
    this.bpSystolic = 120,
    this.bpDiastolic = 80,
    this.pulse = 72,
    this.temperature = 36.5,
    this.weightKg = 70.0,
    this.heightCm = 175.0,
  });

  double get bmi {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    final val = weightKg / (heightM * heightM);
    return double.parse(val.toStringAsFixed(1));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consultation_id': consultationId,
      'bp_systolic': bpSystolic,
      'bp_diastolic': bpDiastolic,
      'pulse': pulse,
      'temperature': temperature,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
    };
  }

  factory VitalSigns.fromMap(Map<String, dynamic> map) {
    return VitalSigns(
      id: map['id'] as int?,
      consultationId: map['consultation_id'] as int?,
      bpSystolic: (map['bp_systolic'] as num?)?.toInt() ?? 120,
      bpDiastolic: (map['bp_diastolic'] as num?)?.toInt() ?? 80,
      pulse: (map['pulse'] as num?)?.toInt() ?? 72,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 36.5,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 70.0,
      heightCm: (map['height_cm'] as num?)?.toDouble() ?? 175.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory VitalSigns.fromJson(String source) => VitalSigns.fromMap(json.decode(source));

  VitalSigns copyWith({
    int? id,
    int? consultationId,
    int? bpSystolic,
    int? bpDiastolic,
    int? pulse,
    double? temperature,
    double? weightKg,
    double? heightCm,
  }) {
    return VitalSigns(
      id: id ?? this.id,
      consultationId: consultationId ?? this.consultationId,
      bpSystolic: bpSystolic ?? this.bpSystolic,
      bpDiastolic: bpDiastolic ?? this.bpDiastolic,
      pulse: pulse ?? this.pulse,
      temperature: temperature ?? this.temperature,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
    );
  }
}

class SoapConsultation {
  final int? id;
  final int patientId;
  final int doctorId;
  final DateTime date;
  final String patientName;
  final String patientCode;
  final String doctorName;
  final VitalSigns vitalSigns;
  final String subjective;
  final String objective;
  final String icd10Code;
  final String assessment;
  final String plan;
  final String status; // 'Draft', 'Finalized'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SoapConsultation({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.patientName,
    required this.patientCode,
    this.doctorName = 'Dr. Smith',
    required this.vitalSigns,
    this.subjective = '',
    this.objective = '',
    this.icd10Code = '',
    this.assessment = '',
    this.plan = '',
    this.status = 'Draft',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'date': date.toIso8601String(),
      'patient_name': patientName,
      'patient_code': patientCode,
      'doctor_name': doctorName,
      'vital_signs': vitalSigns.toMap(),
      'subjective': subjective,
      'objective': objective,
      'icd10_code': icd10Code,
      'assessment': assessment,
      'plan': plan,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SoapConsultation.fromMap(Map<String, dynamic> map) {
    return SoapConsultation(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int,
      date: DateTime.parse(map['date']),
      patientName: map['patient_name'] as String,
      patientCode: map['patient_code'] as String,
      doctorName: map['doctor_name'] as String? ?? 'Dr. Smith',
      vitalSigns: map['vital_signs'] is Map<String, dynamic>
          ? VitalSigns.fromMap(map['vital_signs'])
          : VitalSigns(),
      subjective: map['subjective'] as String? ?? '',
      objective: map['objective'] as String? ?? '',
      icd10Code: map['icd10_code'] as String? ?? '',
      assessment: map['assessment'] as String? ?? '',
      plan: map['plan'] as String? ?? '',
      status: map['status'] as String? ?? 'Draft',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory SoapConsultation.fromJson(String source) =>
      SoapConsultation.fromMap(json.decode(source));
}
