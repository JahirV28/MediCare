import 'dart:convert';

class Appointment {
  final int? id;
  final int patientId;
  final int doctorId;
  final int serviceId;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String status;
  final String? notes;
  // Joined fields
  final String? patientName;
  final String? doctorName;
  final String? serviceName;
  final double? serviceCost;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Appointment({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.serviceId,
    required this.appointmentDate,
    required this.appointmentTime,
    this.status = 'Waiting',
    this.notes,
    this.patientName,
    this.doctorName,
    this.serviceName,
    this.serviceCost,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'service_id': serviceId,
      'appointment_date': appointmentDate.toIso8601String(),
      'appointment_time': appointmentTime,
      'status': status,
      'notes': notes,
      'patient_name': patientName,
      'doctor_name': doctorName,
      'service_name': serviceName,
      'service_cost': serviceCost,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    double? cost;
    if (map['services'] != null && map['services'] is Map) {
      cost = (map['services']['base_cost'] as num?)?.toDouble();
    } else if (map['service_cost'] != null) {
      cost = (map['service_cost'] as num?)?.toDouble();
    }

    return Appointment(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int,
      serviceId: map['service_id'] as int,
      appointmentDate: DateTime.parse(map['appointment_date']),
      appointmentTime: map['appointment_time'] as String,
      status: map['status'] as String? ?? 'Waiting',
      notes: map['notes'] as String?,
      patientName: map['patient_name'] as String?,
      doctorName: map['doctor_name'] as String?,
      serviceName: map['service_name'] as String?,
      serviceCost: cost,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Appointment.fromJson(String source) => Appointment.fromMap(json.decode(source));
}
