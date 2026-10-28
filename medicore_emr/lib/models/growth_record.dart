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
  final String? notes;

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
    this.notes,
  });

  Map<String, dynamic> toMap() {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'measurement_date': dateStr,
      'date': dateStr,
      'age_label': ageLabel,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'weight_percentile': weightPercentile,
      'height_cm': heightCm,
      'height_percentile': heightPercentile,
      'head_circumference_cm': headCircumferenceCm,
      if (notes != null) 'notes': notes,
    };
  }

  factory GrowthRecord.fromMap(Map<String, dynamic> map) {
    final rawDate = map['measurement_date'] ?? map['date'] ?? map['created_at'];
    DateTime parsedDate;
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return GrowthRecord(
      id: map['id'] as int?,
      patientId: (map['patient_id'] as num?)?.toInt() ?? 0,
      date: parsedDate,
      ageLabel: (map['age_label'] as String?) ?? '',
      ageMonths: (map['age_months'] as num?)?.toDouble() ?? 0.0,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0.0,
      weightPercentile: (map['weight_percentile'] as num?)?.toInt() ?? 50,
      heightCm: (map['height_cm'] as num?)?.toDouble() ?? 0.0,
      heightPercentile: (map['height_percentile'] as num?)?.toInt() ?? 50,
      headCircumferenceCm: (map['head_circumference_cm'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory GrowthRecord.fromJson(String source) =>
      GrowthRecord.fromMap(json.decode(source));
}
