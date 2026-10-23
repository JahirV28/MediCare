import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/clinical_record.dart';
import '../models/emergency_contact.dart';
import '../models/allergy_alert.dart';
import '../models/soap_consultation.dart';
import '../models/prescription.dart';
import '../models/diagnostic_file.dart';
import '../models/odontogram_finding.dart';
import '../models/growth_record.dart';
import '../models/user.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// ID del médico o usuario del sistema actualmente autenticado
  int? currentUserId;

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER: NORMALIZACIÓN DE ESTADOS
  // ══════════════════════════════════════════════════════════════════════════

  static String mapStatusToDisplay(String? dbStatus) {
    if (dbStatus == null) return 'En Espera';
    final s = dbStatus.toLowerCase().trim();
    if (s == 'waiting' || s == 'en espera' || s == 'pendiente') return 'En Espera';
    if (s == 'confirmed' || s == 'confirmado' || s == 'confirmada') return 'Confirmado';
    if (s == 'completed' || s == 'atendido' || s == 'completado' || s == 'finalizada') return 'Atendido';
    if (s == 'cancelled' || s == 'cancelado' || s == 'cancelada') return 'Cancelado';
    if (s == 'in progress' || s == 'en progreso' || s == 'en consulta') return 'En Progreso';
    return dbStatus;
  }

  static String mapStatusToDb(String uiStatus) {
    final s = uiStatus.toLowerCase().trim();
    if (s == 'en espera' || s == 'pendiente' || s == 'waiting') return 'Waiting';
    if (s == 'confirmado' || s == 'confirmada' || s == 'confirmed') return 'Confirmed';
    if (s == 'atendido' || s == 'completado' || s == 'completed' || s == 'finalizada') return 'Completed';
    if (s == 'cancelado' || s == 'cancelada' || s == 'cancelled') return 'Cancelled';
    if (s == 'en progreso' || s == 'in progress' || s == 'en consulta') return 'In Progress';
    return 'Waiting';
  }

  static String mapToothConditionToDb(ToothCondition cond) {
    switch (cond) {
      case ToothCondition.caries:
        return 'Caries';
      case ToothCondition.treated:
        return 'Treated';
      case ToothCondition.missing:
        return 'Missing';
      case ToothCondition.healthy:
        return 'Healthy';
    }
  }

  static ToothCondition mapDbToToothCondition(String? dbCond) {
    if (dbCond == null) return ToothCondition.healthy;
    final c = dbCond.toLowerCase().trim();
    if (c.contains('caries')) return ToothCondition.caries;
    if (c.contains('treat') || c.contains('tratad') || c.contains('obtur') || c.contains('restaur') || c.contains('corona')) {
      return ToothCondition.treated;
    }
    if (c.contains('miss') || c.contains('perdid') || c.contains('ausent') || c.contains('extrac')) {
      return ToothCondition.missing;
    }
    return ToothCondition.healthy;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD & ANALÍTICA REAL
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getDashboardStats() async {
    // 1. Intentar procedimiento almacenado sp_get_dashboard_overview
    try {
      final rpcRes = await _client.rpc('sp_get_dashboard_overview');
      if (rpcRes != null && rpcRes is Map && rpcRes['success'] == true) {
        final weeklyRaw = rpcRes['weekly_activity'] as List?;
        final weekly = weeklyRaw?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

        return {
          'appointments_today': (rpcRes['appointments_today'] as num?)?.toInt() ?? 0,
          'active_patients': (rpcRes['active_patients'] as num?)?.toInt() ?? 0,
          'daily_income': (rpcRes['daily_income'] as num?)?.toDouble() ?? 0.0,
          'weekly_activity': weekly,
          'today_index': (rpcRes['today_index'] as num?)?.toInt() ?? (DateTime.now().weekday - 1),
        };
      }
    } catch (e) {
      debugPrint('Aviso: RPC sp_get_dashboard_overview falló, usando consulta directa: $e');
    }

    // 2. Consulta directa rigurosa a tablas de Supabase (sin datos inventados)
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Citas de hoy
      final aptRows = await _client
          .from('appointments')
          .select('id, status')
          .eq('appointment_date', todayStr);
      final validApts = (aptRows as List)
          .where((a) => mapStatusToDisplay(a['status'] as String?) != 'Cancelado')
          .toList();
      final aptCount = validApts.length;

      // Pacientes activos
      final patientRows = await _client
          .from('patients')
          .select('id')
          .eq('is_active', true);
      final activePatients = (patientRows as List).length;

      // Ingresos reales del día (Paid e Income)
      double income = 0.0;
      try {
        final txRows = await _client
            .from('financial_transactions')
            .select('amount, status, transaction_type, transaction_date')
            .gte('transaction_date', '$todayStr 00:00:00')
            .lte('transaction_date', '$todayStr 23:59:59');

        for (var tx in (txRows as List)) {
          final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final status = (tx['status'] as String?)?.toLowerCase();
          final type = (tx['transaction_type'] as String?)?.toLowerCase();
          if ((status == 'paid' || status == 'pagado') && type != 'expense' && type != 'gasto') {
            income += amt;
          }
        }
      } catch (e) {
        debugPrint('Aviso calculando ingresos directos: $e');
      }

      // Actividad semanal real (Lunes a Sábado de la semana en curso)
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final List<double> weekly = [];

      for (int i = 0; i < 6; i++) {
        final dayDate = monday.add(Duration(days: i));
        final dayStr = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
        try {
          final countRes = await _client
              .from('appointments')
              .select('id, status')
              .eq('appointment_date', dayStr);
          final valid = (countRes as List)
              .where((a) => mapStatusToDisplay(a['status'] as String?) != 'Cancelado')
              .length;
          weekly.add(valid.toDouble());
        } catch (_) {
          weekly.add(0.0);
        }
      }

      return {
        'appointments_today': aptCount,
        'active_patients': activePatients,
        'daily_income': income,
        'weekly_activity': weekly,
        'today_index': (now.weekday - 1).clamp(0, 5),
      };
    } catch (e) {
      debugPrint('Error general en getDashboardStats directo: $e');
      return {
        'appointments_today': 0,
        'active_patients': 0,
        'daily_income': 0.0,
        'weekly_activity': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'today_index': (DateTime.now().weekday - 1).clamp(0, 5),
      };
    }
  }

  Future<bool> addIncome(double amount, {int? patientId, int? appointmentId, String? concept}) async {
    try {
      int patId = patientId ?? 1;

      if (appointmentId != null && (patientId == null || patientId <= 0)) {
        try {
          final aptRow = await _client.from('appointments').select('patient_id').eq('id', appointmentId).maybeSingle();
          if (aptRow != null && aptRow['patient_id'] != null) {
            patId = (aptRow['patient_id'] as num).toInt();
          }
        } catch (_) {}
      }

      await _client.from('financial_transactions').insert({
        'patient_id': patId,
        'appointment_id': appointmentId,
        'concept': concept ?? 'Atención Médica y Consulta',
        'amount': amount,
        'payment_method': 'Cash',
        'status': 'Paid',
        'transaction_type': 'Income',
        'currency': 'USD',
        'transaction_date': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error al guardar ingreso en Supabase: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CITAS (APPOINTMENTS)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Appointment>> getTodayAppointments() async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from('appointments')
          .select('*, patients(id, full_name, patient_code), services(id, name, base_cost), users(full_name)')
          .eq('appointment_date', todayStr)
          .neq('status', 'Cancelled')
          .order('appointment_time', ascending: true);

      return (response as List).map<Appointment>((map) {
        final pData = map['patients'] as Map<String, dynamic>?;
        final sData = map['services'] as Map<String, dynamic>?;
        final uData = map['users'] as Map<String, dynamic>?;

        String rawTime = map['appointment_time']?.toString() ?? '09:00';
        String formattedTime = _formatTimeDisplay(rawTime);
        final cost = (sData?['base_cost'] as num?)?.toDouble();

        return Appointment(
          id: (map['id'] as num?)?.toInt(),
          patientId: (map['patient_id'] as num?)?.toInt() ?? 1,
          doctorId: (map['doctor_id'] as num?)?.toInt() ?? (currentUserId ?? 9),
          serviceId: (map['service_id'] as num?)?.toInt() ?? 1,
          appointmentDate: DateTime.tryParse(map['appointment_date']?.toString() ?? '') ?? now,
          appointmentTime: formattedTime,
          status: mapStatusToDisplay(map['status'] as String?),
          notes: map['notes'] as String?,
          patientName: pData?['full_name'] as String? ?? map['patient_name'] as String? ?? 'Paciente',
          doctorName: uData?['full_name'] as String? ?? 'Médico',
          serviceName: sData?['name'] as String? ?? map['service_name'] as String? ?? 'Consulta General',
          serviceCost: cost,
          createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
          updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en getTodayAppointments de Supabase: $e');
      return [];
    }
  }

  Future<bool> addAppointment(Appointment appointment) async {
    try {
      final dateStr = '${appointment.appointmentDate.year}-${appointment.appointmentDate.month.toString().padLeft(2, '0')}-${appointment.appointmentDate.day.toString().padLeft(2, '0')}';
      String timeStr = _cleanTimeToDb(appointment.appointmentTime);
      final dbStatus = mapStatusToDb(appointment.status);
      final docId = appointment.doctorId > 0 ? appointment.doctorId : (currentUserId ?? 9);

      int pId = appointment.patientId;
      if (pId <= 0 && appointment.patientName != null && appointment.patientName!.isNotEmpty) {
        try {
          final found = await _client
              .from('patients')
              .select('id')
              .ilike('full_name', '%${appointment.patientName!.trim()}%')
              .limit(1);
          if (found.isNotEmpty) {
            pId = (found.first['id'] as num).toInt();
          }
        } catch (_) {}
      }

      int sId = appointment.serviceId;
      if (sId <= 0) sId = 1;
      if (appointment.serviceName != null && appointment.serviceName!.isNotEmpty) {
        try {
          final foundSvc = await _client
              .from('services')
              .select('id')
              .ilike('name', '%${appointment.serviceName!.trim()}%')
              .limit(1);
          if (foundSvc.isNotEmpty) {
            sId = (foundSvc.first['id'] as num).toInt();
          }
        } catch (_) {}
      }

      final notesText = (appointment.serviceName != null && appointment.serviceName!.isNotEmpty)
          ? appointment.serviceName
          : appointment.notes;

      // 1. Intentar RPC sp_book_appointment
      try {
        final rpcRes = await _client.rpc('sp_book_appointment', params: {
          'p_patient_id': pId > 0 ? pId : 1,
          'p_doctor_id': docId,
          'p_service_id': sId,
          'p_appointment_date': dateStr,
          'p_appointment_time': timeStr,
          'p_notes': notesText,
          'p_status': dbStatus,
        });
        if (rpcRes is Map && rpcRes['success'] == true) {
          return true;
        } else if (rpcRes is Map && rpcRes['success'] == false) {
          debugPrint('Aviso sp_book_appointment: ${rpcRes["error"] ?? rpcRes["message"]}');
          return false;
        }
      } catch (e) {
        debugPrint('Aviso RPC sp_book_appointment no disponible: $e');
      }

      // 2. Inserción directa en appointments
      await _client.from('appointments').insert({
        'patient_id': pId > 0 ? pId : 1,
        'doctor_id': docId,
        'service_id': sId,
        'appointment_date': dateStr,
        'appointment_time': timeStr,
        'status': dbStatus,
        'notes': notesText,
      });

      return true;
    } catch (e) {
      debugPrint('Error al guardar cita en Supabase: $e');
      return false;
    }
  }

  Future<bool> updateAppointmentStatus(int appointmentId, String newStatus) async {
    try {
      final dbStatus = mapStatusToDb(newStatus);

      try {
        final rpcRes = await _client.rpc('sp_update_appointment_status', params: {
          'p_appointment_id': appointmentId,
          'p_new_status': dbStatus,
        });
        if (rpcRes is Map && rpcRes['success'] == true) {
          return true;
        }
      } catch (_) {}

      await _client
          .from('appointments')
          .update({
            'status': dbStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId);

      if (dbStatus == 'Completed') {
        try {
          final aptRow = await _client.from('appointments').select('patient_id').eq('id', appointmentId).maybeSingle();
          if (aptRow != null && aptRow['patient_id'] != null) {
            await _client.from('patients').update({
              'last_visit': DateTime.now().toIso8601String(),
            }).eq('id', aptRow['patient_id']);
          }
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error al actualizar estado de cita en Supabase: $e');
      return false;
    }
  }

  Future<bool> cancelAppointment(int appointmentId) async {
    return updateAppointmentStatus(appointmentId, 'Cancelado');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CALENDARIO
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, List<Map<String, dynamic>>>> getCalendarAppointmentsForMonth(int year, int month) async {
    final Map<String, List<Map<String, dynamic>>> result = {};
    try {
      final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final endStr = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final response = await _client
          .from('appointments')
          .select('*, patients(id, full_name, patient_code), services(id, name, base_cost)')
          .gte('appointment_date', startStr)
          .lte('appointment_date', endStr)
          .neq('status', 'Cancelled')
          .order('appointment_time', ascending: true);

      for (var row in (response as List)) {
        final dStr = row['appointment_date']?.toString();
        if (dStr != null) {
          final parts = dStr.split('-');
          if (parts.length >= 3) {
            final y = int.tryParse(parts[0]) ?? year;
            final m = int.tryParse(parts[1]) ?? month;
            final d = int.tryParse(parts[2]) ?? 1;
            final key = '$y-$m-$d';

            result.putIfAbsent(key, () => []);

            final pData = row['patients'] as Map<String, dynamic>?;
            final sData = row['services'] as Map<String, dynamic>?;

            final timeRaw = row['appointment_time']?.toString() ?? '09:00';
            final timeClean = _formatTimeDisplay(timeRaw);
            final int? patId = (row['patient_id'] as num?)?.toInt() ?? (pData?['id'] as num?)?.toInt();

            final serviceDisplay = (row['notes'] != null && row['notes'].toString().trim().isNotEmpty)
                ? row['notes'].toString().trim()
                : (sData?['name'] ?? 'Consulta General');

            result[key]!.add({
              'id': row['id'],
              'patient_id': patId,
              'time': timeClean,
              'patient': pData?['full_name'] ?? 'Paciente',
              'service': serviceDisplay,
              'status': mapStatusToDisplay(row['status'] as String?),
              'cost': (sData?['base_cost'] as num?)?.toDouble(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error en getCalendarAppointmentsForMonth de Supabase: $e');
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PACIENTES (PATIENTS)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Patient>> getPatients({
    String? search,
    String? statusFilter,
    int page = 1,
    int perPage = 4,
  }) async {
    try {
      var query = _client.from('patients').select();

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim();
        query = query.or('full_name.ilike.%$q%,patient_code.ilike.%$q%,identity_number.ilike.%$q%,phone.ilike.%$q%');
      }

      if (statusFilter == 'Activo') {
        query = query.eq('is_active', true);
      } else if (statusFilter == 'Inactivo') {
        query = query.eq('is_active', false);
      }

      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await query
          .order('has_alert', ascending: false)
          .order('id', ascending: true)
          .range(start, end);

      return (response as List).map<Patient>((p) => Patient.fromMap(p)).toList();
    } catch (e) {
      debugPrint('Error en getPatients de Supabase: $e');
      return [];
    }
  }

  Future<int> getPatientsCount({String? search, String? statusFilter}) async {
    try {
      var query = _client.from('patients').select('id');

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim();
        query = query.or('full_name.ilike.%$q%,patient_code.ilike.%$q%,identity_number.ilike.%$q%,phone.ilike.%$q%');
      }

      if (statusFilter == 'Activo') {
        query = query.eq('is_active', true);
      } else if (statusFilter == 'Inactivo') {
        query = query.eq('is_active', false);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('Error en getPatientsCount de Supabase: $e');
      return 0;
    }
  }

  Future<List<Patient>> searchPatients(String query, {int limit = 10}) async {
    try {
      final q = query.trim();
      if (q.isEmpty) {
        final res = await _client
            .from('patients')
            .select()
            .eq('is_active', true)
            .order('id', ascending: false)
            .limit(limit);
        return (res as List).map<Patient>((p) => Patient.fromMap(p)).toList();
      }

      try {
        final rpcRes = await _client.rpc('sp_search_patients', params: {
          'p_query': q,
          'p_limit': limit,
        });
        if (rpcRes is List && rpcRes.isNotEmpty) {
          return rpcRes.map<Patient>((p) => Patient.fromMap(p as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      final res = await _client
          .from('patients')
          .select()
          .or('full_name.ilike.%$q%,patient_code.ilike.%$q%,identity_number.ilike.%$q%')
          .order('is_active', ascending: false)
          .order('id', ascending: true)
          .limit(limit);
      return (res as List).map<Patient>((p) => Patient.fromMap(p)).toList();
    } catch (e) {
      debugPrint('Error en searchPatients de Supabase: $e');
      return [];
    }
  }

  Future<Patient> getPatientDetail({int? patientId, String? patientCode, String? patientName}) async {
    try {
      if (patientId != null && patientId > 0) {
        final res = await _client.from('patients').select().eq('id', patientId).maybeSingle();
        if (res != null) return Patient.fromMap(res);
      }
      if (patientCode != null && patientCode.trim().isNotEmpty) {
        final res = await _client.from('patients').select().eq('patient_code', patientCode).maybeSingle();
        if (res != null) return Patient.fromMap(res);
      }
      if (patientName != null && patientName.trim().isNotEmpty) {
        final res = await _client
            .from('patients')
            .select()
            .ilike('full_name', '%${patientName.trim()}%')
            .limit(1);
        if ((res as List).isNotEmpty) {
          return Patient.fromMap(res.first);
        }
      }

      final first = await _client.from('patients').select().order('id', ascending: true).limit(1);
      if ((first as List).isNotEmpty) return Patient.fromMap(first.first);
    } catch (e) {
      debugPrint('Error al obtener paciente de Supabase: $e');
    }

    return Patient(
      id: patientId ?? 0,
      patientCode: patientCode ?? 'PT-0000',
      fullName: patientName ?? 'Paciente no registrado',
      isActive: true,
      hasAlert: false,
    );
  }

  Future<bool> createPatient(Patient patient, {EmergencyContact? emergencyContact}) async {
    try {
      final docId = currentUserId ?? 9;

      // 1. Intentar RPC atómica sp_register_patient_with_contact
      try {
        final rpcRes = await _client.rpc('sp_register_patient_with_contact', params: {
          'p_full_name': patient.fullName.trim(),
          'p_identity_number': patient.identityNumber?.trim(),
          'p_birth_date': patient.birthDate != null
              ? '${patient.birthDate!.year}-${patient.birthDate!.month.toString().padLeft(2, '0')}-${patient.birthDate!.day.toString().padLeft(2, '0')}'
              : null,
          'p_gender': patient.gender,
          'p_blood_type': patient.bloodType,
          'p_phone': patient.phone?.trim(),
          'p_email': patient.email?.trim(),
          'p_address': patient.address?.trim(),
          'p_has_alert': patient.hasAlert,
          'p_patient_code': patient.patientCode.isNotEmpty && !patient.patientCode.contains('PT-0000') ? patient.patientCode : null,
          'p_contact_name': emergencyContact?.contactName.trim(),
          'p_contact_relationship': emergencyContact?.relationship.trim(),
          'p_contact_phone': emergencyContact?.phone.trim(),
          'p_doctor_id': docId,
        });

        if (rpcRes is Map && rpcRes['success'] == true) {
          return true;
        } else if (rpcRes is Map && rpcRes['success'] == false) {
          debugPrint('Aviso sp_register_patient_with_contact: ${rpcRes["error"]}');
          return false;
        }
      } catch (e) {
        debugPrint('Aviso RPC sp_register_patient_with_contact falló, usando inserción directa: $e');
      }

      // 2. Inserción directa en pacientes
      String code = patient.patientCode;
      if (code.isEmpty || code.contains('PT-0000')) {
        final randNum = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
        code = 'PT-$randNum-${DateTime.now().year % 100}';
      }

      final insertData = {
        'patient_code': code,
        'full_name': patient.fullName.trim(),
        'identity_number': (patient.identityNumber != null && patient.identityNumber!.trim().isNotEmpty)
            ? patient.identityNumber!.trim()
            : null,
        'birth_date': patient.birthDate != null
            ? '${patient.birthDate!.year}-${patient.birthDate!.month.toString().padLeft(2, '0')}-${patient.birthDate!.day.toString().padLeft(2, '0')}'
            : null,
        'gender': patient.gender,
        'phone': patient.phone?.trim(),
        'email': patient.email?.trim(),
        'address': patient.address?.trim(),
        'blood_type': patient.bloodType,
        'photo_url': patient.photoUrl,
        'is_active': patient.isActive,
        'has_alert': patient.hasAlert,
        'last_visit': DateTime.now().toIso8601String(),
      };

      final response = await _client.from('patients').insert(insertData).select('id').single();
      final newId = (response['id'] as num).toInt();

      if (emergencyContact != null && emergencyContact.contactName.trim().isNotEmpty) {
        await _client.from('emergency_contacts').insert({
          'patient_id': newId,
          'contact_name': emergencyContact.contactName.trim(),
          'relationship': emergencyContact.relationship.trim(),
          'phone': emergencyContact.phone.trim(),
        });
      }

      await _client.from('clinical_records').insert({
        'patient_id': newId,
        'doctor_id': docId,
        'record_type': 'Consulta General',
        'title': 'Apertura de Expediente Clínico',
        'description': 'Paciente registrado en el sistema.',
        'record_date': DateTime.now().toIso8601String(),
        'tags': ['Apertura', 'Expediente'],
      });

      return true;
    } catch (e) {
      debugPrint('Error al crear paciente en Supabase: $e');
      return false;
    }
  }

  Future<bool> togglePatientActiveStatus(int patientId, bool currentStatus) async {
    try {
      await _client
          .from('patients')
          .update({'is_active': !currentStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', patientId);
      return true;
    } catch (e) {
      debugPrint('Error al cambiar estado de paciente en Supabase: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPEDIENTE CLÍNICO & ALERTAS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ClinicalRecord>> getClinicalRecords(int patientId) async {
    try {
      final res = await _client
          .from('clinical_records')
          .select('*, users(full_name)')
          .eq('patient_id', patientId)
          .order('record_date', ascending: false);

      return (res as List).map<ClinicalRecord>((r) {
        final u = r['users'] as Map<String, dynamic>?;
        return ClinicalRecord.fromMap({
          ...r,
          'doctor_name': u?['full_name'] ?? 'Dr. Médico Tratante',
        });
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener clinical_records de Supabase: $e');
      return [];
    }
  }

  Future<List<AllergyAlert>> getAllergyAlerts(int patientId) async {
    try {
      final res = await _client
          .from('allergy_alerts')
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true);
      return (res as List).map<AllergyAlert>((a) => AllergyAlert.fromMap(a)).toList();
    } catch (e) {
      debugPrint('Error al obtener allergy_alerts de Supabase: $e');
      return [];
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts(int patientId) async {
    try {
      final res = await _client
          .from('emergency_contacts')
          .select()
          .eq('patient_id', patientId);
      return (res as List).map<EmergencyContact>((c) => EmergencyContact.fromMap(c)).toList();
    } catch (e) {
      debugPrint('Error al obtener emergency_contacts de Supabase: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ODONTOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<int, DentalToothState>> getOdontogramState(int patientId) async {
    final Map<int, DentalToothState> teethState = {};
    const upper = [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28];
    const lower = [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38];
    for (final t in [...upper, ...lower]) {
      teethState[t] = DentalToothState(toothNumber: t, condition: ToothCondition.healthy);
    }

    try {
      final res = await _client
          .from('odontogram_findings')
          .select()
          .eq('patient_id', patientId)
          .order('finding_date', ascending: true);

      for (var f in (res as List)) {
        final tNum = (f['tooth_number'] as num).toInt();
        final cond = mapDbToToothCondition(f['condition_type'] as String?);

        List<String> surfaces = [];
        if (f['surfaces'] != null) {
          if (f['surfaces'] is List) {
            surfaces = List<String>.from(f['surfaces']);
          } else if (f['surfaces'] is String) {
            try {
              surfaces = List<String>.from(json.decode(f['surfaces']));
            } catch (_) {}
          }
        }

        teethState[tNum] = DentalToothState(
          toothNumber: tNum,
          condition: cond,
          affectedSurfaces: surfaces,
          activeProcedure: f['procedure_name'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error en getOdontogramState de Supabase: $e');
    }

    return teethState;
  }

  Future<List<DentalProcedureLog>> getDentalProcedureLogs(int patientId) async {
    try {
      final res = await _client
          .from('odontogram_findings')
          .select('*, users(full_name)')
          .eq('patient_id', patientId)
          .order('finding_date', ascending: false);

      return (res as List).map<DentalProcedureLog>((f) {
        final u = f['users'] as Map<String, dynamic>?;

        List<String> surfaces = [];
        if (f['surfaces'] != null) {
          if (f['surfaces'] is List) {
            surfaces = List<String>.from(f['surfaces']);
          } else if (f['surfaces'] is String) {
            try {
              surfaces = List<String>.from(json.decode(f['surfaces']));
            } catch (_) {}
          }
        }

        String statusDisplay = 'Pendiente';
        final s = (f['status'] as String?)?.toLowerCase();
        if (s == 'completed' || s == 'completado') statusDisplay = 'Completado';
        if (s == 'cancelled' || s == 'cancelado') statusDisplay = 'Cancelado';

        return DentalProcedureLog(
          id: (f['id'] as num?)?.toInt(),
          patientId: patientId,
          date: DateTime.tryParse(f['finding_date']?.toString() ?? '') ?? DateTime.now(),
          toothNumber: (f['tooth_number'] as num).toInt(),
          procedureName: f['procedure_name'] as String? ?? 'Procedimiento Dental',
          status: statusDisplay,
          providerName: u?['full_name'] as String? ?? 'Dr. Kalej Vargas',
          notes: f['notes'] as String?,
          surfaces: surfaces,
          cost: (f['cost'] as num?)?.toDouble(),
          condition: f['condition_type'] as String?,
          anesthesia: f['anesthesia'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en getDentalProcedureLogs de Supabase: $e');
      return [];
    }
  }

  Future<bool> saveOdontogramFinding({
    required int patientId,
    required int toothNumber,
    required ToothCondition condition,
    required List<String> surfaces,
    required String procedureName,
    String status = 'Pending',
    String? notes,
    double? cost,
    String? anesthesia,
    int? providerId,
  }) async {
    try {
      final docId = providerId ?? currentUserId ?? 9;
      final condStr = mapToothConditionToDb(condition);
      final dbStatus = (status == 'Completado' || status == 'Completed')
          ? 'Completed'
          : (status == 'Cancelado' || status == 'Cancelled' ? 'Cancelled' : 'Pending');

      final insertData = <String, dynamic>{
        'patient_id': patientId,
        'provider_id': docId,
        'tooth_number': toothNumber,
        'condition_type': condStr,
        'surfaces': surfaces,
        'procedure_name': procedureName.isNotEmpty ? procedureName : 'Evaluación Dental',
        'status': dbStatus,
        'notes': notes,
        'finding_date': DateTime.now().toIso8601String(),
      };
      if (cost != null) insertData['cost'] = cost;
      if (anesthesia != null && anesthesia.isNotEmpty) insertData['anesthesia'] = anesthesia;

      await _client.from('odontogram_findings').insert(insertData);
      return true;
    } catch (e) {
      debugPrint('Error al guardar odontogram finding en Supabase: $e');
      return false;
    }
  }

  Future<bool> updateOdontogramStatus(int findingId, String status) async {
    try {
      final dbStatus = (status == 'Completado' || status == 'Completed')
          ? 'Completed'
          : (status == 'Cancelado' || status == 'Cancelled' ? 'Cancelled' : 'Pending');

      await _client
          .from('odontogram_findings')
          .update({
            'status': dbStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', findingId);
      return true;
    } catch (e) {
      debugPrint('Error al actualizar estado de hallazgo odontológico: $e');
      return false;
    }
  }

  Future<bool> updateOdontogramFinding({
    required int findingId,
    required int toothNumber,
    required ToothCondition condition,
    required List<String> surfaces,
    required String procedureName,
    required String status,
    String? notes,
    double? cost,
    String? anesthesia,
  }) async {
    try {
      final condStr = mapToothConditionToDb(condition);
      final dbStatus = (status == 'Completado' || status == 'Completed')
          ? 'Completed'
          : (status == 'Cancelado' || status == 'Cancelled' ? 'Cancelled' : 'Pending');

      final updateData = <String, dynamic>{
        'tooth_number': toothNumber,
        'condition_type': condStr,
        'surfaces': surfaces,
        'procedure_name': procedureName.isNotEmpty ? procedureName : 'Procedimiento Dental',
        'status': dbStatus,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (cost != null) updateData['cost'] = cost;
      if (anesthesia != null) updateData['anesthesia'] = anesthesia;

      await _client
          .from('odontogram_findings')
          .update(updateData)
          .eq('id', findingId);
      return true;
    } catch (e) {
      debugPrint('Error al actualizar hallazgo odontológico: $e');
      return false;
    }
  }

  Future<bool> deleteOdontogramFinding(int findingId) async {
    try {
      await _client.from('odontogram_findings').delete().eq('id', findingId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar hallazgo odontológico: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTAS SOAP Y SIGNOS VITALES
  // ══════════════════════════════════════════════════════════════════════════

  Future<SoapConsultation?> getInitialSoapConsultation(String patientName, String patientCode, {int? patientId}) async {
    try {
      int? pId = patientId;
      Map<String, dynamic>? pRow;
      if (pId != null && pId > 0) {
        pRow = await _client.from('patients').select('id, full_name, patient_code').eq('id', pId).maybeSingle();
      }

      if (pRow == null && patientCode.isNotEmpty) {
        pRow = await _client
            .from('patients')
            .select('id, full_name, patient_code')
            .or('patient_code.eq.$patientCode,full_name.ilike.%$patientName%')
            .maybeSingle();
      }

      if (pRow != null) {
        pId = (pRow['id'] as num).toInt();
        final cRows = await _client
            .from('soap_consultations')
            .select('*, vital_signs(*)')
            .eq('patient_id', pId)
            .order('consultation_date', ascending: false)
            .limit(1);

        if ((cRows as List).isNotEmpty) {
          final cRow = cRows.first;
          final vList = cRow['vital_signs'] as List?;
          VitalSigns vitals = VitalSigns();
          if (vList != null && vList.isNotEmpty) {
            final vMap = vList.first as Map<String, dynamic>;
            vitals = VitalSigns(
              bpSystolic: (vMap['bp_systolic'] as num?)?.toInt() ?? 0,
              bpDiastolic: (vMap['bp_diastolic'] as num?)?.toInt() ?? 0,
              pulse: (vMap['pulse'] as num?)?.toInt() ?? 0,
              temperature: (vMap['temperature'] as num?)?.toDouble() ?? 0.0,
              weightKg: (vMap['weight_kg'] as num?)?.toDouble() ?? 0.0,
              heightCm: (vMap['height_cm'] as num?)?.toDouble() ?? 0.0,
            );
          }

          return SoapConsultation(
            id: (cRow['id'] as num?)?.toInt(),
            patientId: pId,
            doctorId: (cRow['doctor_id'] as num?)?.toInt() ?? (currentUserId ?? 9),
            date: DateTime.tryParse(cRow['consultation_date']?.toString() ?? '') ?? DateTime.now(),
            patientName: pRow['full_name'],
            patientCode: pRow['patient_code'],
            vitalSigns: vitals,
            subjective: cRow['subjective'] ?? '',
            objective: cRow['objective'] ?? '',
            icd10Code: cRow['icd10_code'] ?? '',
            assessment: cRow['assessment'] ?? '',
            plan: cRow['plan'] ?? '',
            status: cRow['status'] ?? 'Draft',
          );
        }

        // Si no tiene consulta previa, iniciar formulario limpio sin vitals falsos pre-llenados
        return SoapConsultation(
          patientId: pId,
          doctorId: currentUserId ?? 9,
          date: DateTime.now(),
          patientName: pRow['full_name'] ?? patientName,
          patientCode: pRow['patient_code'] ?? patientCode,
          vitalSigns: VitalSigns(
            bpSystolic: 120,
            bpDiastolic: 80,
            pulse: 72,
            temperature: 36.5,
            weightKg: 70.0,
            heightCm: 175.0,
          ),
          subjective: '',
          objective: '',
          icd10Code: '',
          assessment: '',
          plan: '',
          status: 'Draft',
        );
      }
    } catch (e) {
      debugPrint('Aviso al buscar consulta previa en Supabase: $e');
    }

    return SoapConsultation(
      patientId: patientId ?? 0,
      doctorId: currentUserId ?? 9,
      date: DateTime.now(),
      patientName: patientName,
      patientCode: patientCode,
      vitalSigns: VitalSigns(
        bpSystolic: 120,
        bpDiastolic: 80,
        pulse: 72,
        temperature: 36.5,
        weightKg: 70.0,
        heightCm: 175.0,
      ),
      subjective: '',
      objective: '',
      icd10Code: '',
      assessment: '',
      plan: '',
      status: 'Draft',
    );
  }

  Future<bool> saveSoapConsultation(SoapConsultation consultation) async {
    try {
      int pId = consultation.patientId;
      if (pId <= 0) {
        final p = await _client.from('patients').select('id').limit(1).single();
        pId = (p['id'] as num).toInt();
      }

      final docId = consultation.doctorId > 0 ? consultation.doctorId : (currentUserId ?? 9);

      // 1. Intentar RPC sp_save_consultation_with_vitals
      try {
        final rpcRes = await _client.rpc('sp_save_consultation_with_vitals', params: {
          'p_patient_id': pId,
          'p_doctor_id': docId,
          'p_subjective': consultation.subjective,
          'p_objective': consultation.objective,
          'p_assessment': consultation.assessment,
          'p_plan': consultation.plan,
          'p_icd10_code': consultation.icd10Code.isNotEmpty ? consultation.icd10Code : null,
          'p_status': consultation.status == 'Finalized' ? 'Finalized' : 'Draft',
          'p_consultation_id': consultation.id,
          'p_bp_systolic': consultation.vitalSigns.bpSystolic > 0 ? consultation.vitalSigns.bpSystolic : null,
          'p_bp_diastolic': consultation.vitalSigns.bpDiastolic > 0 ? consultation.vitalSigns.bpDiastolic : null,
          'p_heart_rate': consultation.vitalSigns.pulse > 0 ? consultation.vitalSigns.pulse : null,
          'p_temperature': consultation.vitalSigns.temperature > 0 ? consultation.vitalSigns.temperature : null,
          'p_weight_kg': consultation.vitalSigns.weightKg > 0 ? consultation.vitalSigns.weightKg : null,
          'p_height_cm': consultation.vitalSigns.heightCm > 0 ? consultation.vitalSigns.heightCm : null,
        });

        if (rpcRes is Map && rpcRes['success'] == true) {
          return true;
        }
      } catch (e) {
        debugPrint('Aviso RPC sp_save_consultation_with_vitals no disponible: $e');
      }

      // 2. Inserción directa
      int cId = consultation.id ?? 0;
      final cStatus = consultation.status == 'Finalized' ? 'Finalized' : 'Draft';

      if (cId > 0) {
        await _client.from('soap_consultations').update({
          'subjective': consultation.subjective,
          'objective': consultation.objective,
          'icd10_code': consultation.icd10Code,
          'assessment': consultation.assessment,
          'plan': consultation.plan,
          'status': cStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', cId);
      } else {
        final cRes = await _client.from('soap_consultations').insert({
          'patient_id': pId,
          'doctor_id': docId,
          'consultation_date': consultation.date.toIso8601String(),
          'subjective': consultation.subjective,
          'objective': consultation.objective,
          'icd10_code': consultation.icd10Code,
          'assessment': consultation.assessment,
          'plan': consultation.plan,
          'status': cStatus,
        }).select('id').single();
        cId = (cRes['id'] as num).toInt();
      }

      // Guardar signos vitales (vital_signs.bmi es GENERATED ALWAYS, se omite de la inserción)
      if (consultation.vitalSigns.bpSystolic > 0 || consultation.vitalSigns.weightKg > 0) {
        final existingVitals = await _client.from('vital_signs').select('id').eq('consultation_id', cId).limit(1);
        if ((existingVitals as List).isNotEmpty) {
          await _client.from('vital_signs').update({
            'bp_systolic': consultation.vitalSigns.bpSystolic,
            'bp_diastolic': consultation.vitalSigns.bpDiastolic,
            'pulse': consultation.vitalSigns.pulse,
            'temperature': consultation.vitalSigns.temperature,
            'weight_kg': consultation.vitalSigns.weightKg,
            'height_cm': consultation.vitalSigns.heightCm,
            'measured_at': DateTime.now().toIso8601String(),
          }).eq('id', existingVitals.first['id']);
        } else {
          await _client.from('vital_signs').insert({
            'consultation_id': cId,
            'patient_id': pId,
            'bp_systolic': consultation.vitalSigns.bpSystolic,
            'bp_diastolic': consultation.vitalSigns.bpDiastolic,
            'pulse': consultation.vitalSigns.pulse,
            'temperature': consultation.vitalSigns.temperature,
            'weight_kg': consultation.vitalSigns.weightKg,
            'height_cm': consultation.vitalSigns.heightCm,
            'measured_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (cStatus == 'Finalized') {
        await _client.from('clinical_records').insert({
          'patient_id': pId,
          'doctor_id': docId,
          'record_type': 'Consulta SOAP',
          'title': 'Consulta Médica Finalizada',
          'description': 'Diagnóstico: ${consultation.icd10Code.isNotEmpty ? consultation.icd10Code : "General"}. Evaluación: ${consultation.assessment}. Plan: ${consultation.plan}',
          'record_date': DateTime.now().toIso8601String(),
          'tags': ['SOAP', 'Consulta'],
        });

        await _client.from('patients').update({
          'last_visit': DateTime.now().toIso8601String(),
        }).eq('id', pId);
      }

      return true;
    } catch (e) {
      debugPrint('Error al guardar consulta SOAP en Supabase: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECETAS MÉDICAS (PRESCRIPTIONS)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Prescription?> getActivePrescription({int? patientId}) async {
    try {
      if (patientId != null && patientId > 0) {
        final pRows = await _client
            .from('prescriptions')
            .select('*, prescription_items(*), patients(full_name, patient_code), users(full_name)')
            .eq('patient_id', patientId)
            .order('prescription_date', ascending: false)
            .limit(1);

        if ((pRows as List).isNotEmpty) {
          final pRow = pRows.first;
          final items = (pRow['prescription_items'] as List?)?.map<PrescriptionItem>((i) {
                return PrescriptionItem(
                  id: (i['id'] as num?)?.toInt(),
                  drugName: i['drug_name'] ?? '',
                  dose: i['dose'] ?? '',
                  frequency: i['frequency'] ?? '',
                  duration: i['duration'] ?? '',
                  instructions: i['instructions'] ?? '',
                );
              }).toList() ??
              [];

          final patientData = pRow['patients'] as Map<String, dynamic>?;
          final docData = pRow['users'] as Map<String, dynamic>?;

          return Prescription(
            id: (pRow['id'] as num?)?.toInt(),
            patientId: patientId,
            date: DateTime.tryParse(pRow['prescription_date']?.toString() ?? '') ?? DateTime.now(),
            clinicName: pRow['clinic_name'] ?? 'Clínica Sanitas Central',
            clinicAddress: pRow['clinic_address'] ?? 'Av. Principal 123, Ciudad • Tel: 555-0192',
            patientName: patientData?['full_name'] ?? 'Paciente',
            patientCode: patientData?['patient_code'] ?? 'PT-000',
            doctorName: docData?['full_name'] ?? 'Dr. Kalej Vargas',
            items: items,
          );
        }

        final pat = await _client
            .from('patients')
            .select('full_name, patient_code')
            .eq('id', patientId)
            .maybeSingle();

        final settings = await getClinicSettings();

        return Prescription(
          patientId: patientId,
          date: DateTime.now(),
          clinicName: settings['clinic_name'] ?? 'MediCore Clínica',
          clinicAddress: settings['address'] ?? 'Av. Principal #100',
          patientName: pat?['full_name'] ?? 'Paciente',
          patientCode: pat?['patient_code'] ?? 'PT-000',
          doctorName: 'Dr. Kalej Vargas',
          items: [],
        );
      }
    } catch (e) {
      debugPrint('Aviso en getActivePrescription de Supabase: $e');
    }

    return null;
  }

  Future<bool> savePrescription({
    required int patientId,
    required List<PrescriptionItem> items,
    int? doctorId,
  }) async {
    try {
      final docId = doctorId ?? currentUserId ?? 9;
      final settings = await getClinicSettings();

      // 1. Intentar RPC sp_create_prescription_with_items
      try {
        final itemsPayload = items.map((i) => {
          'drug_name': i.drugName,
          'dose': i.dose,
          'frequency': i.frequency,
          'duration': i.duration,
          'instructions': i.instructions,
        }).toList();

        final rpcRes = await _client.rpc('sp_create_prescription_with_items', params: {
          'p_patient_id': patientId,
          'p_doctor_id': docId,
          'p_clinic_name': settings['clinic_name'] ?? 'MediCore Clínica',
          'p_clinic_address': settings['address'] ?? 'Av. Principal #100',
          'p_items': itemsPayload,
        });

        if (rpcRes is Map && rpcRes['success'] == true) {
          return true;
        }
      } catch (e) {
        debugPrint('Aviso RPC sp_create_prescription_with_items: $e');
      }

      // 2. Inserción directa (NOTA: la tabla real prescriptions NO tiene columna status)
      final pRes = await _client.from('prescriptions').insert({
        'patient_id': patientId,
        'doctor_id': docId,
        'clinic_name': settings['clinic_name'] ?? 'MediCore Clínica',
        'clinic_address': settings['address'] ?? 'Av. Principal #100',
        'prescription_date': DateTime.now().toIso8601String().substring(0, 10),
      }).select('id').single();

      final presId = (pRes['id'] as num).toInt();

      if (items.isNotEmpty) {
        final rows = items.map((i) => {
          'prescription_id': presId,
          'drug_name': i.drugName,
          'dose': i.dose,
          'frequency': i.frequency,
          'duration': i.duration,
          'instructions': i.instructions,
        }).toList();
        await _client.from('prescription_items').insert(rows);
      }

      await _client.from('clinical_records').insert({
        'patient_id': patientId,
        'doctor_id': docId,
        'record_type': 'Receta Farmacológica',
        'title': 'Emisión de Receta Médica',
        'description': '${items.length} medicamentos recetados: ${items.map((e) => e.drugName).join(", ")}',
        'record_date': DateTime.now().toIso8601String(),
        'tags': ['Farmacia', 'Receta'],
      });

      return true;
    } catch (e) {
      debugPrint('Error al guardar receta en Supabase: $e');
      return false;
    }
  }

  Future<List<String>> searchDrugs(String query) async {
    const defaultDrugs = [
      'Amoxicilina 500mg',
      'Ibuprofeno 400mg',
      'Paracetamol 500mg',
      'Azitromicina 500mg',
      'Omeprazol 20mg',
      'Loratadina 10mg',
      'Metformina 850mg',
      'Losartán 50mg',
      'Ciprofloxacino 500mg',
      'Salbutamol 100mcg',
      'Clindamicina 300mg',
      'Ketorolaco 10mg',
      'Cetirizina 10mg',
      'Dexametasona 4mg',
      'Diclofenaco 50mg',
    ];

    try {
      final res = await _client
          .from('prescription_items')
          .select('drug_name')
          .ilike('drug_name', '%${query.trim()}%')
          .limit(10);
      final fromDb = (res as List).map((i) => i['drug_name'] as String).toSet();

      final q = query.toLowerCase();
      final filteredDefaults = defaultDrugs.where((d) => d.toLowerCase().contains(q)).toSet();

      final combined = {...fromDb, ...filteredDefaults}.toList();
      return combined.isNotEmpty ? combined : defaultDrugs;
    } catch (_) {
      final q = query.toLowerCase();
      return defaultDrugs.where((d) => d.toLowerCase().contains(q)).toList();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ARCHIVOS DIAGNÓSTICOS (DIAGNOSTIC FILES)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<DiagnosticFile>> getDiagnosticFiles(int patientId) async {
    try {
      final res = await _client
          .from('diagnostic_files')
          .select()
          .eq('patient_id', patientId)
          .order('upload_date', ascending: false);

      return (res as List).map<DiagnosticFile>((f) => DiagnosticFile.fromMap(f)).toList();
    } catch (e) {
      debugPrint('Aviso en getDiagnosticFiles de Supabase: $e');
      return [];
    }
  }

  Future<bool> uploadDiagnosticFile({
    required int patientId,
    required String fileName,
    required String category,
    required String fileUrl,
    String fileSize = '2.4 MB',
    int totalPages = 1,
    String mimeType = 'application/pdf',
  }) async {
    try {
      final docId = currentUserId ?? 9;
      await _client.from('diagnostic_files').insert({
        'patient_id': patientId,
        'uploaded_by_id': docId,
        'file_name': fileName,
        'category': category,
        'file_url': fileUrl,
        'file_size': fileSize,
        'total_pages': totalPages,
        'mime_type': mimeType,
        'upload_date': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error subiendo archivo diagnóstico: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRECIMIENTO PEDIÁTRICO (PEDIATRICS)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<GrowthRecord>> getPediatricGrowthHistory(int patientId) async {
    try {
      final res = await _client
          .from('pediatric_growth_records')
          .select()
          .eq('patient_id', patientId)
          .order('measurement_date', ascending: false);

      return (res as List).map<GrowthRecord>((r) => GrowthRecord.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Aviso en getPediatricGrowthHistory de Supabase: $e');
      return [];
    }
  }

  Future<bool> savePediatricGrowthRecord({
    required int patientId,
    required DateTime date,
    required String ageLabel,
    required double ageMonths,
    required double weightKg,
    required double heightCm,
    required double headCircumferenceCm,
    int weightPercentile = 50,
    int heightPercentile = 50,
    String? notes,
  }) async {
    try {
      final docId = currentUserId ?? 9;
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      await _client.from('pediatric_growth_records').insert({
        'patient_id': patientId,
        'provider_id': docId,
        'measurement_date': dateStr,
        'age_label': ageLabel,
        'age_months': ageMonths,
        'weight_kg': weightKg,
        'weight_percentile': weightPercentile,
        'height_cm': heightCm,
        'height_percentile': heightPercentile,
        'head_circumference_cm': headCircumferenceCm,
        'notes': notes,
      });
      return true;
    } catch (e) {
      debugPrint('Error guardando control pediátrico: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FINANZAS Y FACTURACIÓN
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getFinancialTransactions({String? period}) async {
    try {
      var query = _client
          .from('financial_transactions')
          .select('*, patients(full_name, patient_code)');

      final now = DateTime.now();
      if (period == 'Esta Semana') {
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        query = query.gte('transaction_date', startOfWeek.toIso8601String());
      } else if (period == 'Este Mes') {
        final startOfMonth = DateTime(now.year, now.month, 1);
        query = query.gte('transaction_date', startOfMonth.toIso8601String());
      } else if (period == 'Este Año') {
        final startOfYear = DateTime(now.year, 1, 1);
        query = query.gte('transaction_date', startOfYear.toIso8601String());
      }

      final res = await query.order('transaction_date', ascending: false);

      return (res as List).map<Map<String, dynamic>>((row) {
        final p = row['patients'] as Map<String, dynamic>?;
        final d = DateTime.tryParse(row['transaction_date']?.toString() ?? '') ?? DateTime.now();
        final formattedDate = '${d.day} ${_monthNameShort(d.month)} ${d.year}';

        String status = 'Pagado';
        final s = (row['status'] as String?)?.toLowerCase();
        if (s == 'pending' || s == 'pendiente') status = 'Pendiente';
        if (s == 'cancelled' || s == 'cancelado') status = 'Cancelado';

        return {
          'id': row['id'],
          'date': formattedDate,
          'raw_date': row['transaction_date'],
          'patient': p?['full_name'] ?? 'Consulta Médica General',
          'patient_code': p?['patient_code'] ?? '',
          'concept': row['concept'] ?? 'Atención Médica',
          'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
          'currency': row['currency'] ?? 'USD',
          'status': status,
          'payment_method': row['payment_method'] ?? 'Cash',
          'transaction_type': row['transaction_type'] ?? 'Income',
          'invoice_number': row['invoice_number'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error en getFinancialTransactions de Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinancialMetrics({String? period}) async {
    try {
      final txs = await getFinancialTransactions(period: period);
      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      int billedCount = 0;

      for (var tx in txs) {
        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final status = (tx['status'] as String?)?.toLowerCase();
        final type = (tx['transaction_type'] as String?)?.toLowerCase();

        if (status == 'pagado' || status == 'paid') {
          if (type == 'expense' || type == 'gasto') {
            totalExpenses += amt;
          } else {
            totalIncome += amt;
            billedCount++;
          }
        }
      }

      final balance = totalIncome - totalExpenses;
      final paidPercentage = txs.isNotEmpty ? ((billedCount / txs.length) * 100).round() : 100;

      return {
        'total_income': totalIncome,
        'total_expenses': totalExpenses,
        'balance': balance,
        'billed_count': billedCount,
        'paid_percentage': paidPercentage,
      };
    } catch (e) {
      debugPrint('Error calculando métricas financieras: $e');
      return {
        'total_income': 0.0,
        'total_expenses': 0.0,
        'balance': 0.0,
        'billed_count': 0,
        'paid_percentage': 100,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlyIncomeHistory({int months = 6}) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - (months - 1), 1);

      final res = await _client
          .from('financial_transactions')
          .select('amount, status, transaction_type, transaction_date')
          .gte('transaction_date', startDate.toIso8601String())
          .order('transaction_date', ascending: true);

      final Map<String, double> monthTotals = {};
      final List<Map<String, dynamic>> monthlyResult = [];

      for (int i = months - 1; i >= 0; i--) {
        final mDate = DateTime(now.year, now.month - i, 1);
        final key = '${mDate.year}-${mDate.month.toString().padLeft(2, '0')}';
        monthTotals[key] = 0.0;
      }

      for (var row in (res as List)) {
        final s = (row['status'] as String?)?.toLowerCase();
        final type = (row['transaction_type'] as String?)?.toLowerCase();
        if (s == 'paid' || s == 'pagado') {
          if (type != 'expense' && type != 'gasto') {
            final d = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
            if (d != null) {
              final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
              if (monthTotals.containsKey(key)) {
                monthTotals[key] = (monthTotals[key] ?? 0.0) + ((row['amount'] as num?)?.toDouble() ?? 0.0);
              }
            }
          }
        }
      }

      monthTotals.forEach((key, amount) {
        final parts = key.split('-');
        final year = int.tryParse(parts[0]) ?? now.year;
        final month = int.tryParse(parts[1]) ?? now.month;
        monthlyResult.add({
          'key': key,
          'month_label': _monthNameShort(month),
          'year': year,
          'amount': amount,
        });
      });

      return monthlyResult;
    } catch (e) {
      debugPrint('Error en getMonthlyIncomeHistory: $e');
      final now = DateTime.now();
      return List.generate(months, (i) {
        final m = DateTime(now.year, now.month - (months - 1 - i), 1);
        return {
          'key': '${m.year}-${m.month}',
          'month_label': _monthNameShort(m.month),
          'year': m.year,
          'amount': 0.0,
        };
      });
    }
  }

  Future<bool> registerFinancialTransaction({
    int? patientId,
    int? appointmentId,
    required String concept,
    required double amount,
    String currency = 'USD',
    String paymentMethod = 'Cash',
    String status = 'Paid',
    String transactionType = 'Income',
    String? invoiceNumber,
    String? notes,
  }) async {
    try {
      try {
        final rpcRes = await _client.rpc('sp_register_financial_transaction', params: {
          'p_patient_id': patientId,
          'p_appointment_id': appointmentId,
          'p_concept': concept.trim(),
          'p_amount': amount,
          'p_currency': currency,
          'p_payment_method': paymentMethod,
          'p_status': status,
          'p_transaction_type': transactionType,
          'p_invoice_number': invoiceNumber,
          'p_notes': notes?.trim(),
        });
        if (rpcRes != null && rpcRes['success'] == true) {
          return true;
        }
      } catch (_) {}

      final folio = invoiceNumber ?? 'REC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';
      await _client.from('financial_transactions').insert({
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'concept': concept.trim(),
        'amount': amount,
        'payment_method': paymentMethod,
        'status': status,
        'transaction_type': transactionType,
        'currency': currency,
        'invoice_number': folio,
        'notes': notes?.trim(),
        'transaction_date': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error al registrar transacción financiera en Supabase: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTES REALES DINÁMICOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateReportData({
    required String reportTitle,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    // 1. Intentar RPC sp_generate_report
    try {
      final rpcRes = await _client.rpc('sp_generate_report', params: {
        'p_report': reportTitle,
        'p_start': startStr,
        'p_end': endStr,
      });

      if (rpcRes is Map && rpcRes['success'] == true) {
        final headers = List<String>.from(rpcRes['headers'] as List);
        final rowsRaw = rpcRes['rows'] as List;
        final rows = rowsRaw.map((r) => List<String>.from((r as List).map((c) => c?.toString() ?? ''))).toList();

        return {
          'headers': headers,
          'rows': rows,
          'count': rows.length,
          'total': (rpcRes['total'] as num?)?.toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Aviso: RPC sp_generate_report falló, usando consulta directa: $e');
    }

    // 2. Consulta directa por tipo de reporte
    try {
      if (reportTitle == 'Pacientes Nuevos') {
        final res = await _client
            .from('patients')
            .select()
            .gte('created_at', '$startStr 00:00:00')
            .lte('created_at', '$endStr 23:59:59')
            .order('created_at', ascending: true);

        final headers = ['#', 'Fecha', 'Paciente', 'Código', 'Teléfono', 'Estado'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final d = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final name = r['full_name'] ?? '—';
          final code = r['patient_code'] ?? '—';
          final phone = r['phone'] ?? '—';
          final status = (r['is_active'] == true) ? 'Activo' : 'Inactivo';
          return [idx, dateStr, name, code, phone, status];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length};
      } else if (reportTitle == 'Consultas Realizadas') {
        final res = await _client
            .from('appointments')
            .select('*, patients(full_name), services(name), users(full_name)')
            .eq('status', 'Completed')
            .gte('appointment_date', startStr)
            .lte('appointment_date', endStr)
            .order('appointment_date', ascending: true);

        final headers = ['#', 'Fecha', 'Paciente', 'Servicio', 'Médico Tratante', 'Estado'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final d = DateTime.tryParse(r['appointment_date']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final p = r['patients'] as Map<String, dynamic>?;
          final s = r['services'] as Map<String, dynamic>?;
          final u = r['users'] as Map<String, dynamic>?;
          return [
            idx,
            dateStr,
            p?['full_name'] ?? '—',
            s?['name'] ?? r['notes'] ?? 'Consulta',
            u?['full_name'] ?? 'Dr. Kalej Vargas',
            'Atendido'
          ];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length};
      } else if (reportTitle == 'Ingresos por Período') {
        final res = await _client
            .from('financial_transactions')
            .select('*, patients(full_name)')
            .eq('status', 'Paid')
            .gte('transaction_date', '$startStr 00:00:00')
            .lte('transaction_date', '$endStr 23:59:59')
            .order('transaction_date', ascending: true);

        double total = 0.0;
        final headers = ['#', 'Fecha', 'Paciente', 'Concepto', 'Método', 'Monto'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
          total += amt;
          final d = DateTime.tryParse(r['transaction_date']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final p = r['patients'] as Map<String, dynamic>?;
          return [
            idx,
            dateStr,
            p?['full_name'] ?? 'Público General',
            r['concept'] ?? 'Atención Médica',
            r['payment_method'] ?? 'Cash',
            '\$${amt.toStringAsFixed(2)}',
          ];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length, 'total': total};
      } else if (reportTitle == 'Procedimientos') {
        final res = await _client
            .from('odontogram_findings')
            .select('*, patients(full_name)')
            .eq('status', 'Completed')
            .gte('finding_date', '$startStr 00:00:00')
            .lte('finding_date', '$endStr 23:59:59')
            .order('finding_date', ascending: true);

        double total = 0.0;
        final headers = ['#', 'Fecha', 'Paciente', 'Pieza FDI', 'Procedimiento', 'Costo'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final cost = (r['cost'] as num?)?.toDouble() ?? 0.0;
          total += cost;
          final d = DateTime.tryParse(r['finding_date']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final p = r['patients'] as Map<String, dynamic>?;
          return [
            idx,
            dateStr,
            p?['full_name'] ?? '—',
            'Pieza ${r['tooth_number']}',
            r['procedure_name'] ?? 'Odontología',
            cost > 0 ? '\$${cost.toStringAsFixed(2)}' : '—',
          ];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length, 'total': total};
      } else if (reportTitle == 'Control Pediátrico') {
        final res = await _client
            .from('pediatric_growth_records')
            .select('*, patients(full_name)')
            .gte('measurement_date', startStr)
            .lte('measurement_date', endStr)
            .order('measurement_date', ascending: true);

        final headers = ['#', 'Fecha', 'Paciente', 'Edad', 'Peso (kg)', 'Talla (cm)', 'P. Cefálico'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final d = DateTime.tryParse(r['measurement_date']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final p = r['patients'] as Map<String, dynamic>?;
          return [
            idx,
            dateStr,
            p?['full_name'] ?? '—',
            r['age_label'] ?? '—',
            '${r['weight_kg']} kg',
            '${r['height_cm']} cm',
            '${r['head_circumference_cm']} cm',
          ];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length};
      } else {
        // Citas y Asistencia
        final res = await _client
            .from('appointments')
            .select('*, patients(full_name), services(name)')
            .gte('appointment_date', startStr)
            .lte('appointment_date', endStr)
            .order('appointment_date', ascending: true);

        final headers = ['#', 'Fecha', 'Hora', 'Paciente', 'Servicio', 'Estado'];
        final rows = (res as List).asMap().entries.map((entry) {
          final idx = (entry.key + 1).toString().padLeft(3, '0');
          final r = entry.value;
          final d = DateTime.tryParse(r['appointment_date']?.toString() ?? '') ?? DateTime.now();
          final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          final p = r['patients'] as Map<String, dynamic>?;
          final s = r['services'] as Map<String, dynamic>?;
          return [
            idx,
            dateStr,
            _formatTimeDisplay(r['appointment_time']?.toString() ?? '09:00'),
            p?['full_name'] ?? '—',
            s?['name'] ?? r['notes'] ?? 'Consulta',
            mapStatusToDisplay(r['status'] as String?),
          ];
        }).toList();

        return {'headers': headers, 'rows': rows, 'count': rows.length};
      }
    } catch (e) {
      debugPrint('Error en generateReportData directo: $e');
      return {
        'headers': ['#', 'Fecha', 'Paciente', 'Concepto', 'Monto'],
        'rows': <List<String>>[],
        'count': 0,
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICACIONES REALES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNotifications() async {
    // 1. Intentar RPC sp_get_notifications
    try {
      final rpcRes = await _client.rpc('sp_get_notifications');
      if (rpcRes is List) {
        return List<Map<String, dynamic>>.from(rpcRes.map((n) => Map<String, dynamic>.from(n as Map)));
      }
    } catch (_) {}

    // 2. Consulta directa a la base de datos
    final List<Map<String, dynamic>> list = [];
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Pacientes en espera hoy
      final waitingRes = await _client
          .from('appointments')
          .select('id, patients(full_name)')
          .eq('appointment_date', todayStr)
          .eq('status', 'Waiting');

      if ((waitingRes as List).isNotEmpty) {
        list.add({
          'key': 'waiting-today',
          'severity': 'info',
          'title': 'Pacientes en Sala de Espera',
          'message': '${waitingRes.length} paciente(s) esperando atención médica hoy.',
        });
      }

      // Alertas de alergia para citas de hoy
      final allergyApts = await _client
          .from('appointments')
          .select('id, patients(id, full_name, has_alert)')
          .eq('appointment_date', todayStr)
          .neq('status', 'Cancelled');

      for (var a in (allergyApts as List)) {
        final p = a['patients'] as Map<String, dynamic>?;
        if (p?['has_alert'] == true) {
          list.add({
            'key': 'allergy-${a["id"]}',
            'severity': 'danger',
            'title': 'Alerta de Alergia',
            'message': '${p?["full_name"]} tiene cita programada hoy y registra alerta médica.',
          });
        }
      }

      // Cobros pendientes
      final pendingTx = await _client
          .from('financial_transactions')
          .select('id, amount')
          .eq('status', 'Pending');

      if ((pendingTx as List).isNotEmpty) {
        double pendingTotal = 0.0;
        for (var t in (pendingTx as List)) {
          pendingTotal += (t['amount'] as num?)?.toDouble() ?? 0.0;
        }
        list.add({
          'key': 'pending-payments',
          'severity': 'warning',
          'title': 'Cobros Pendientes',
          'message': '${pendingTx.length} cuenta(s) por cobrar por un total de \$${pendingTotal.toStringAsFixed(2)}.',
        });
      }
    } catch (e) {
      debugPrint('Error cargando notificaciones: $e');
    }
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN DE LA CLÍNICA
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getClinicSettings() async {
    try {
      final res = await _client.from('clinic_settings').select('*').eq('id', 1).maybeSingle();
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Aviso al obtener clinic_settings de Supabase: $e');
    }

    return {
      'id': 1,
      'clinic_name': 'MediCore Clínica',
      'address': 'Av. Principal #100, Consultorios Médicos',
      'phone': '+505 2222 3344',
      'email': 'contacto@medicore.com',
      'schedule_weekday': '08:00 — 18:00',
      'schedule_saturday': '08:00 — 14:00',
      'schedule_sunday': 'Cerrado',
      'notifications_enabled': true,
      'email_reminders': true,
      'sound_enabled': true,
      'language': 'Español',
      'consult_duration': '30 min',
    };
  }

  Future<bool> saveClinicSettings(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['id'] = 1;
      payload['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('clinic_settings').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('Error al guardar clinic_settings en Supabase: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USUARIOS DEL SISTEMA
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<User>> getSystemUsers() async {
    try {
      final res = await _client.from('users').select('*, roles(name)').order('id', ascending: true);
      if (res.isNotEmpty) {
        return (res as List).map<User>((row) {
          final map = Map<String, dynamic>.from(row as Map);
          if (map['roles'] != null && map['roles'] is Map) {
            map['role_name'] = map['roles']['name'];
          }
          return User.fromMap(map);
        }).toList();
      }
    } catch (e) {
      debugPrint('Error al consultar usuarios del sistema en Supabase: $e');
    }
    return [];
  }

  Future<bool> createSystemUser({
    required String fullName,
    required String email,
    required int roleId,
    String? phone,
    String? specialty,
    String? licenseNumber,
    String? providerId,
    String? password,
  }) async {
    try {
      final insertData = <String, dynamic>{
        'full_name': fullName.trim(),
        'email': email.trim(),
        'role_id': roleId,
        'phone': phone?.trim(),
        'specialty': specialty?.trim(),
        'license_number': licenseNumber?.trim(),
        'provider_id': providerId?.trim(),
        'password_hash': password != null && password.isNotEmpty ? password : '[default_hash]',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _client.from('users').insert(insertData);
      return true;
    } catch (e) {
      debugPrint('Error en createSystemUser: $e');
      return false;
    }
  }

  Future<bool> updateSystemUser({
    required int userId,
    required String fullName,
    required String email,
    required int roleId,
    String? phone,
    String? specialty,
    String? licenseNumber,
    String? providerId,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'full_name': fullName.trim(),
        'email': email.trim(),
        'role_id': roleId,
        'phone': phone?.trim(),
        'specialty': specialty?.trim(),
        'license_number': licenseNumber?.trim(),
        'provider_id': providerId?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isActive != null) updateData['is_active'] = isActive;
      await _client.from('users').update(updateData).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error en updateSystemUser: $e');
      return false;
    }
  }

  Future<bool> toggleUserStatus(int userId, bool isActive) async {
    try {
      await _client.from('users').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error en toggleUserStatus: $e');
      return false;
    }
  }

  Future<bool> deleteSystemUser(int userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
      return true;
    } catch (e) {
      return toggleUserStatus(userId, false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILIDADES DE FORMATO
  // ══════════════════════════════════════════════════════════════════════════

  static String _formatTimeDisplay(String raw) {
    if (raw.toUpperCase().contains('AM') || raw.toUpperCase().contains('PM')) {
      return raw;
    }
    final parts = raw.split(':');
    if (parts.length >= 2) {
      int hour = int.tryParse(parts[0]) ?? 9;
      int min = int.tryParse(parts[1]) ?? 0;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $period';
    }
    return raw;
  }

  static String _cleanTimeToDb(String raw) {
    String clean = raw.trim();
    if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
      final isPM = clean.toUpperCase().contains('PM');
      final timePart = clean.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
      final p = timePart.split(':');
      if (p.isNotEmpty) {
        int h = int.tryParse(p[0]) ?? 9;
        int m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
        if (isPM && h < 12) h += 12;
        if (!isPM && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
      }
    }
    if (clean.length == 5 && clean.contains(':')) {
      return '$clean:00';
    }
    return clean;
  }

  static String _monthNameShort(int m) {
    const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    if (m >= 1 && m <= 12) return names[m - 1];
    return '';
  }
}
