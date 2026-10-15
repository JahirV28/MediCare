import 'dart:convert';

enum ToothCondition {
  healthy,
  caries,
  treated,
  missing,
}

class DentalToothState {
  final int toothNumber;
  final ToothCondition condition;
  final List<String> affectedSurfaces; // 'M', 'O', 'D', 'B', 'L'
  final String? activeProcedure;

  const DentalToothState({
    required this.toothNumber,
    this.condition = ToothCondition.healthy,
    this.affectedSurfaces = const [],
    this.activeProcedure,
  });

  DentalToothState copyWith({
    int? toothNumber,
    ToothCondition? condition,
    List<String>? affectedSurfaces,
    String? activeProcedure,
  }) {
    return DentalToothState(
      toothNumber: toothNumber ?? this.toothNumber,
      condition: condition ?? this.condition,
      affectedSurfaces: affectedSurfaces ?? this.affectedSurfaces,
      activeProcedure: activeProcedure ?? this.activeProcedure,
    );
  }
}

class DentalProcedureLog {
  final int? id;
  final int patientId;
  final DateTime date;
  final int toothNumber;
  final String procedureName;
  final String status; // 'Pending', 'Completed', 'Cancelled'
  final String providerName;
  final String? notes;
  final List<String> surfaces;
  final double? cost;
  final String? condition;
  final String? anesthesia;

  DentalProcedureLog({
    this.id,
    required this.patientId,
    required this.date,
    required this.toothNumber,
    required this.procedureName,
    required this.status,
    required this.providerName,
    this.notes,
    this.surfaces = const [],
    this.cost,
    this.condition,
    this.anesthesia,
  });

  DentalProcedureLog copyWith({
    int? id,
    int? patientId,
    DateTime? date,
    int? toothNumber,
    String? procedureName,
    String? status,
    String? providerName,
    String? notes,
    List<String>? surfaces,
    double? cost,
    String? condition,
    String? anesthesia,
  }) {
    return DentalProcedureLog(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      toothNumber: toothNumber ?? this.toothNumber,
      procedureName: procedureName ?? this.procedureName,
      status: status ?? this.status,
      providerName: providerName ?? this.providerName,
      notes: notes ?? this.notes,
      surfaces: surfaces ?? this.surfaces,
      cost: cost ?? this.cost,
      condition: condition ?? this.condition,
      anesthesia: anesthesia ?? this.anesthesia,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'date': date.toIso8601String(),
      'tooth_number': toothNumber,
      'procedure_name': procedureName,
      'status': status,
      'provider_name': providerName,
      'notes': notes,
      'surfaces': json.encode(surfaces),
      'cost': cost,
      'condition': condition,
      'anesthesia': anesthesia,
    };
  }

  factory DentalProcedureLog.fromMap(Map<String, dynamic> map) {
    List<String> parsedSurfaces = [];
    if (map['surfaces'] != null) {
      if (map['surfaces'] is List) {
        parsedSurfaces = List<String>.from(map['surfaces']);
      } else if (map['surfaces'] is String) {
        try {
          parsedSurfaces = List<String>.from(json.decode(map['surfaces']));
        } catch (_) {}
      }
    }
    return DentalProcedureLog(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      date: DateTime.parse(map['date']),
      toothNumber: (map['tooth_number'] as num).toInt(),
      procedureName: map['procedure_name'] as String,
      status: map['status'] as String,
      providerName: map['provider_name'] as String,
      notes: map['notes'] as String?,
      surfaces: parsedSurfaces,
      cost: (map['cost'] as num?)?.toDouble(),
      condition: map['condition'] as String?,
      anesthesia: map['anesthesia'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory DentalProcedureLog.fromJson(String source) =>
      DentalProcedureLog.fromMap(json.decode(source));
}

class DmftSummary {
  final int decayed;
  final int missing;
  final int filled;

  const DmftSummary({
    required this.decayed,
    required this.missing,
    required this.filled,
  });

  int get dmftScore => decayed + missing + filled;
}
