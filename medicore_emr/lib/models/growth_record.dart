import 'dart:convert';

class GrowthRecord {
  final int? id;
  final int patientId;
  final DateTime date;
  final String ageLabel;
  final double ageMonths;
  final double weightKg;
  final int weightPercentile;
  final double heightCm;
  final int heightPercentile;
  final double headCircumferenceCm; // PC

  GrowthRecord({
    this.id,
    required this.patientId,
    required this.date,
    required this.ageLabel,
    required this.ageMonths,
    required this.weightKg,
    required this.weightPercentile,
    required this.heightCm,
    required this.heightPercentile,
    required this.headCircumferenceCm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'date': date.toIso8601String(),
      'age_label': ageLabel,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'weight_percentile': weightPercentile,
      'height_cm': heightCm,
      'height_percentile': heightPercentile,
      'head_circumference_cm': headCircumferenceCm,
    };
  }

  factory GrowthRecord.fromMap(Map<String, dynamic> map) {
    return GrowthRecord(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      date: DateTime.parse(map['date']),
      ageLabel: map['age_label'] as String,
      ageMonths: (map['age_months'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      weightPercentile: (map['weight_percentile'] as num).toInt(),
      heightCm: (map['height_cm'] as num).toDouble(),
      heightPercentile: (map['height_percentile'] as num).toInt(),
      headCircumferenceCm: (map['head_circumference_cm'] as num).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GrowthRecord.fromJson(String source) =>
      GrowthRecord.fromMap(json.decode(source));
}
