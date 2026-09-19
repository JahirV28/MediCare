import '../models/user.dart';
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

class MockApiService {
  // Singleton
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  // ──────────────────── AUTH ────────────────────
  Future<User?> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if ((username == 'dr.smith@medicore.com' || username == 'DRS-001') &&
        password == 'password123') {
      return _users[0];
    }
    // Allow demo fallback login
    if (username.isNotEmpty && password.isNotEmpty) {
      return _users[0];
    }
    return null;
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  double _dailyIncome = 300.0;

  // ──────────────────── DASHBOARD ────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final activeCount = _patients.where((p) => p.isActive).length;
    final aptCount = _appointments.where((a) => a.status != 'Cancelado').length;
    return {
      'appointments_today': aptCount,
      'active_patients': activeCount,
      'daily_income': _dailyIncome,
      'weekly_activity': [8.0, 12.0, 6.0, 15.0, (activeCount > 0 ? activeCount.toDouble() : 10.0), (aptCount > 0 ? (aptCount * 3).toDouble() : 4.0)],
    };
  }

  Future<void> addIncome(double amount) async {
    _dailyIncome += amount;
  }

  // ──────────────────── APPOINTMENTS ────────────────────
  Future<List<Appointment>> getTodayAppointments() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_appointments);
  }

  Future<bool> addAppointment(Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nextId = (_appointments.map((a) => a.id ?? 0).fold(0, (a, b) => a > b ? a : b)) + 1;
    final newApt = Appointment(
      id: nextId,
      patientId: appointment.patientId,
      doctorId: appointment.doctorId,
      serviceId: appointment.serviceId,
      appointmentDate: appointment.appointmentDate,
      appointmentTime: appointment.appointmentTime,
      status: appointment.status,
      notes: appointment.notes,
      patientName: appointment.patientName,
      doctorName: appointment.doctorName,
      serviceName: appointment.serviceName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _appointments.add(newApt);
    return true;
  }

  Future<bool> updateAppointmentStatus(int appointmentId, String newStatus) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final old = _appointments[index];
      _appointments[index] = Appointment(
        id: old.id,
        patientId: old.patientId,
        doctorId: old.doctorId,
        serviceId: old.serviceId,
        appointmentDate: old.appointmentDate,
        appointmentTime: old.appointmentTime,
        status: newStatus,
        notes: old.notes,
        patientName: old.patientName,
        doctorName: old.doctorName,
        serviceName: old.serviceName,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  Future<bool> cancelAppointment(int appointmentId) async {
    return updateAppointmentStatus(appointmentId, 'Cancelado');
  }

  // ──────────────────── PATIENTS ────────────────────
  Future<List<Patient>> getPatients({String? search, int page = 1, int perPage = 4}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    List<Patient> filtered = List.from(_patients);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      filtered = filtered.where((p) =>
        p.fullName.toLowerCase().contains(q) ||
        p.patientCode.toLowerCase().contains(q) ||
        (p.identityNumber?.toLowerCase().contains(q) ?? false) ||
        (p.phone?.contains(q) ?? false)
      ).toList();
    }
    final start = (page - 1) * perPage;
    if (start >= filtered.length) {
      return [];
    }
    final end = (start + perPage) > filtered.length ? filtered.length : (start + perPage);
    return filtered.sublist(start, end);
  }

  Future<int> getPatientsCount({String? search}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      return _patients.where((p) =>
        p.fullName.toLowerCase().contains(q) ||
        p.patientCode.toLowerCase().contains(q) ||
        (p.identityNumber?.toLowerCase().contains(q) ?? false) ||
        (p.phone?.contains(q) ?? false)
      ).length;
    }
    return _patients.length;
  }

  Future<Patient?> getPatientByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _patients.firstWhere((p) => p.patientCode == code);
    } catch (_) {
      return null;
    }
  }

  Future<Patient> getPatientDetail({int? patientId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (patientId != null) {
      try {
        return _patients.firstWhere((p) => p.id == patientId);
      } catch (_) {}
    }
    return _patients.isNotEmpty ? _patients.first : _detailPatient;
  }

  Future<bool> createPatient(Patient patient, {EmergencyContact? emergencyContact}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final nextId = (_patients.map((p) => p.id ?? 0).fold(0, (a, b) => a > b ? a : b)) + 1;
    final newPatient = patient.copyWith(id: nextId);
    _patients.insert(0, newPatient);

    if (emergencyContact != null) {
      _emergencyContacts.add(emergencyContact.copyWith(
        id: _emergencyContacts.length + 1,
        patientId: nextId,
      ));
    }
    return true;
  }

  Future<bool> togglePatientActiveStatus(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _patients.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      final p = _patients[index];
      _patients[index] = p.copyWith(isActive: !p.isActive);
      return true;
    }
    return false;
  }

  Future<Patient?> getPatientByIdOrName(int? id, String? name) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (id != null) {
      try {
        return _patients.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    if (name != null && name.trim().isNotEmpty) {
      final q = name.trim().toLowerCase();
      try {
        return _patients.firstWhere((p) =>
          p.fullName.toLowerCase().contains(q) || q.contains(p.fullName.toLowerCase())
        );
      } catch (_) {}
    }
    return _patients.isNotEmpty ? _patients.first : null;
  }

  // ──────────────────── CLINICAL RECORDS ────────────────────
  Future<List<ClinicalRecord>> getClinicalRecords(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = _clinicalRecords.where((r) => r.patientId == patientId).toList();
    if (list.isEmpty) {
      return [
        ClinicalRecord(
          id: 100 + patientId,
          patientId: patientId,
          doctorId: 1,
          recordType: 'CONSULTA GENERAL',
          title: 'Apertura de Expediente Clínico',
          description: 'Paciente registrado en el sistema. Signos vitales estables y antecedentes clínicos documentados.',
          recordDate: DateTime.now(),
          tags: ['Dr. Smith', 'Medicina General'],
          doctorName: 'Dr. Smith',
        ),
      ];
    }
    return list;
  }

  // ──────────────────── EMERGENCY CONTACTS ────────────────────
  Future<List<EmergencyContact>> getEmergencyContacts(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _emergencyContacts.where((e) => e.patientId == patientId).toList();
  }

  // ──────────────────── ALLERGY ALERTS ────────────────────
  Future<List<AllergyAlert>> getAllergyAlerts(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _allergyAlerts.where((a) => a.patientId == patientId).toList();
  }

  // ──────────────────── SOAP CONSULTATION ────────────────────
  Future<SoapConsultation> getInitialSoapConsultation(String patientName, String patientCode) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SoapConsultation(
      patientId: 987654,
      doctorId: 1,
      date: DateTime(2023, 10, 24),
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
      subjective: 'Paciente masculino refiere cefalea tensional recurrente y fatiga moderada durante jornadas laborales.',
      objective: 'Paciente consciente, orientado. Auscultación cardiopulmonar sin soplos ni ruidos agregados. Abdomen blando, no doloroso a la palpación profunda.',
      icd10Code: 'G44.2 - Cefalea tensional',
      assessment: 'Cefalea de tipo tensional asociada a estrés postural y privación parcial del sueño.',
      plan: '1. Medidas de higiene postural.\n2. Ibuprofeno 400mg cada 8 horas si hay dolor intenso.\n3. Control en 2 semanas con bitácora de síntomas.',
    );
  }

  Future<bool> saveSoapConsultation(SoapConsultation consultation) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  // ──────────────────── PRESCRIPTION BUILDER ────────────────────
  Future<Prescription> getActivePrescription() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _samplePrescription;
  }

  Future<List<String>> searchDrugs(String query) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final drugs = [
      'Amoxicilina 500mg',
      'Amoxicilina + Ácido Clavulánico 875/125mg',
      'Azitromicina 500mg',
      'Ciprofloxacino 500mg',
      'Ibuprofeno 400mg',
      'Ibuprofeno 600mg',
      'Ketorolaco 10mg',
      'Metformina 850mg',
      'Omeprazol 20mg',
      'Paracetamol 500mg',
      'Paracetamol 1g',
      'Losartán 50mg',
      'Salbutamol Aerosol 100mcg',
    ];
    if (query.isEmpty) return drugs;
    return drugs.where((d) => d.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // ──────────────────── DIAGNOSTIC FILES ────────────────────
  Future<List<DiagnosticFile>> getDiagnosticFiles(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _diagnosticFiles;
  }

  // ──────────────────── ODONTOLOGY ────────────────────
  Future<Map<int, DentalToothState>> getOdontogramState(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Map<int, DentalToothState>.from(_initialOdontogram);
  }

  Future<List<DentalProcedureLog>> getDentalProcedureLogs(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dentalLogs;
  }

  Future<DmftSummary> getDmftSummary(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return const DmftSummary(decayed: 2, missing: 0, filled: 2);
  }

  // ──────────────────── PEDIATRICS ────────────────────
  Future<List<GrowthRecord>> getPediatricGrowthHistory(int patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _growthRecords;
  }

  // ════════════════════ MOCK DATA STORAGE ════════════════════

  final List<User> _users = [
    User(
      id: 1,
      fullName: 'Dr. Smith',
      email: 'dr.smith@medicore.com',
      providerId: 'DRS-001',
      roleId: 2,
      roleName: 'Doctor',
      isActive: true,
    ),
    User(
      id: 2,
      fullName: 'Dr. Rodriguez',
      email: 'dr.rodriguez@medicore.com',
      providerId: 'DRR-002',
      roleId: 2,
      roleName: 'Doctor',
    ),
    User(
      id: 3,
      fullName: 'Dr. Martinez',
      email: 'dr.martinez@medicore.com',
      providerId: 'DRM-003',
      roleId: 2,
      roleName: 'Doctor',
    ),
  ];

  final List<Appointment> _appointments = [
    Appointment(
      id: 1,
      patientId: 5,
      doctorId: 1,
      serviceId: 1,
      appointmentDate: DateTime.now(),
      appointmentTime: '09:00 AM',
      status: 'Waiting',
      patientName: 'Julio Cortez',
      serviceName: 'General Checkup',
    ),
    Appointment(
      id: 2,
      patientId: 6,
      doctorId: 1,
      serviceId: 2,
      appointmentDate: DateTime.now(),
      appointmentTime: '09:30 AM',
      status: 'Confirmed',
      patientName: 'Maria Rodriguez',
      serviceName: 'Odontology Consult',
    ),
    Appointment(
      id: 3,
      patientId: 7,
      doctorId: 1,
      serviceId: 3,
      appointmentDate: DateTime.now(),
      appointmentTime: '10:15 AM',
      status: 'Confirmed',
      patientName: 'Antonio Silva',
      serviceName: 'Pediatrics - Vaccine',
    ),
  ];

  final List<Patient> _patients = [
    Patient(
      id: 1,
      patientCode: 'PT-8492',
      fullName: 'Ana Martínez Silva',
      identityNumber: '001-150378-0001A',
      birthDate: DateTime(1978, 3, 15),
      gender: 'Femenino',
      phone: '+505 8492 1234',
      email: 'ana.martinez@email.com',
      address: 'Colonia Los Robles, Casa 45, Managua',
      bloodType: 'A+',
      isActive: true,
      lastVisit: DateTime(2023, 10, 12),
    ),
    Patient(
      id: 2,
      patientCode: 'PT-3104',
      fullName: 'Carlos Ruiz Torres',
      identityNumber: '001-220791-0002B',
      birthDate: DateTime(1991, 7, 22),
      gender: 'Masculino',
      phone: '+505 8976 5432',
      email: 'carlos.ruiz@email.com',
      address: 'Barrio Sutiaba, Costado Sur Iglesia, León',
      bloodType: 'B+',
      isActive: true,
      lastVisit: DateTime(2023, 11, 5),
    ),
    Patient(
      id: 3,
      patientCode: 'PT-9921',
      fullName: 'Laura Gómez Pérez',
      identityNumber: '281-081155-0003C',
      birthDate: DateTime(1955, 11, 8),
      gender: 'Femenino',
      phone: '+505 8344 6677',
      email: 'laura.gomez@email.com',
      address: 'Calle Real Xalteva, Granada',
      bloodType: 'O-',
      isActive: true,
      hasAlert: true,
      lastVisit: DateTime.now(),
    ),
    Patient(
      id: 4,
      patientCode: 'PT-1045',
      fullName: 'Miguel Vargas López',
      identityNumber: '401-300594-0004D',
      birthDate: DateTime(1994, 5, 30),
      gender: 'Masculino',
      phone: '+505 8122 4455',
      email: 'miguel.vargas@email.com',
      address: 'Barrio Palo Alto, Matagalpa',
      bloodType: 'AB+',
      isActive: true,
      lastVisit: DateTime(2023, 8, 28),
    ),
    Patient(
      id: 5,
      patientCode: 'PT-5520',
      fullName: 'Julio Cortez Mendoza',
      identityNumber: '001-140885-0005E',
      birthDate: DateTime(1985, 8, 14),
      gender: 'Masculino',
      phone: '+505 8654 3210',
      email: 'julio.cortez@email.com',
      address: 'Villa Fontana Norte, Managua',
      bloodType: 'O+',
      isActive: true,
      lastVisit: DateTime.now(),
    ),
    Patient(
      id: 6,
      patientCode: 'PT-5521',
      fullName: 'María Rodríguez Jarquín',
      identityNumber: '001-190990-0006F',
      birthDate: DateTime(1990, 9, 19),
      gender: 'Femenino',
      phone: '+505 8765 4321',
      email: 'maria.rodriguez@email.com',
      address: 'Barrio San Jerónimo, Masaya',
      bloodType: 'A-',
      isActive: true,
      lastVisit: DateTime.now(),
    ),
    Patient(
      id: 7,
      patientCode: 'PT-5522',
      fullName: 'Antonio Silva Blandón',
      identityNumber: '001-050415-0007G',
      birthDate: DateTime(2015, 4, 5),
      gender: 'Masculino',
      phone: '+505 8899 0011',
      email: 'antonio.silva@email.com',
      address: 'Reparto San Juan, Estelí',
      bloodType: 'O+',
      isActive: true,
      lastVisit: DateTime.now(),
    ),
  ];

  final Patient _detailPatient = Patient(
    id: 5,
    patientCode: 'PT-5520',
    fullName: 'Julio Cortez Mendoza',
    identityNumber: '001-140885-0005E',
    birthDate: DateTime(1985, 8, 14),
    gender: 'Masculino',
    phone: '+505 8654 3210',
    email: 'julio.cortez@email.com',
    address: 'Villa Fontana Norte, Managua',
    bloodType: 'O+',
    isActive: true,
  );

  final List<ClinicalRecord> _clinicalRecords = [
    ClinicalRecord(
      id: 1,
      patientId: 5,
      doctorId: 2,
      recordType: 'CONSULTA GENERAL',
      title: 'Control Anual y Revisión de Laboratorios',
      description:
          'Paciente acude para revisión de rutina. Refiere dolor leve en zona lumbar tras esfuerzo físico. Laboratorios dentro de parámetros normales excepto colesterol ligeramente elevado.',
      recordDate: DateTime(2023, 10, 24, 10, 30),
      tags: ['Dr. Rodriguez', 'Medicina Interna'],
      doctorName: 'Dr. Rodriguez',
    ),
    ClinicalRecord(
      id: 2,
      patientId: 5,
      doctorId: 3,
      recordType: 'ESTUDIO DE IMAGEN',
      title: 'Radiografía Lumbar AP/Lateral',
      description:
          'Solicitado por Dr. Martínez por lumbalgia persistente. Resultados pendientes de interpretación formal.',
      recordDate: DateTime(2023, 9, 15, 8, 15),
      doctorName: 'Dr. Martinez',
    ),
  ];

  final List<EmergencyContact> _emergencyContacts = [
    EmergencyContact(
      id: 1,
      patientId: 5,
      contactName: 'Elena Mendoza',
      relationship: 'Esposa',
      phone: '+52 55 5678-1234',
    ),
  ];

  final List<AllergyAlert> _allergyAlerts = [
    AllergyAlert(
      id: 1,
      patientId: 5,
      allergen: 'Penicilina',
      reaction: 'Reacción Anafiláctica Severa',
      severity: 'Severa',
      documentedDate: DateTime(2021, 5, 12),
      isActive: true,
    ),
  ];

  final Prescription _samplePrescription = Prescription(
    id: 1,
    patientId: 101,
    patientName: 'Ana García López',
    patientCode: 'PT-8472',
    patientAge: 34,
    patientWeightKg: 62,
    patientAllergies: 'Penicilina',
    clinicName: 'Clínica Sanitas Central',
    clinicAddress: 'Av. Principal 123, Ciudad • Tel: 555-0192',
    doctorName: 'Dr. Carlos Mendoza',
    professionalLicense: 'C.M. 45892',
    date: DateTime(2023, 10, 24),
    items: [
      PrescriptionItem(
        id: 1,
        drugName: 'Ibuprofeno 600mg',
        dose: '1 comprimido',
        frequency: 'Cada 8h',
        duration: '5 días',
        instructions: 'Tomar 1 comprimido cada 8h durante 5 días.',
      ),
      PrescriptionItem(
        id: 2,
        drugName: 'Omeprazol 20mg',
        dose: '1 cápsula',
        frequency: 'Cada 24h (mañanas)',
        duration: '14 días',
        instructions: 'Tomar 1 cápsula cada 24h (mañanas) durante 14 días. Tomar en ayunas.',
      ),
    ],
  );

  final List<DiagnosticFile> _diagnosticFiles = [
    DiagnosticFile(
      id: 1,
      patientId: 84729,
      fileName: 'Chest_XRay_AP.dcm',
      category: 'Imaging',
      uploadDate: DateTime(2023, 10, 12, 11, 20),
      uploadedBy: 'Dr. Martinez',
      fileUrl: 'https://example.com/files/chest.dcm',
      fileSize: '18.4 MB',
      totalPages: 1,
      mimeType: 'image/jpeg',
    ),
    DiagnosticFile(
      id: 2,
      patientId: 84729,
      fileName: 'Blood_Panel_Q3.pdf',
      category: 'Lab Results',
      uploadDate: DateTime(2023, 10, 10, 14, 32),
      uploadedBy: 'Nurse Adams',
      fileUrl: 'https://example.com/files/blood_panel.pdf',
      fileSize: '2.4 MB',
      totalPages: 3,
      mimeType: 'application/pdf',
    ),
    DiagnosticFile(
      id: 3,
      patientId: 84729,
      fileName: 'Referral_Cardio.pdf',
      category: 'Referrals',
      uploadDate: DateTime(2023, 9, 28, 9, 15),
      uploadedBy: 'Dr. Smith',
      fileUrl: 'https://example.com/files/referral.pdf',
      fileSize: '850 KB',
      totalPages: 1,
      mimeType: 'application/pdf',
    ),
    DiagnosticFile(
      id: 4,
      patientId: 84729,
      fileName: 'Dermatology_Biopsy.pdf',
      category: 'Dermatology',
      uploadDate: DateTime(2023, 9, 15, 16, 40),
      uploadedBy: 'Dr. Collins',
      fileUrl: 'https://example.com/files/biopsy.pdf',
      fileSize: '4.1 MB',
      totalPages: 2,
      mimeType: 'application/pdf',
    ),
  ];

  final Map<int, DentalToothState> _initialOdontogram = {
    18: const DentalToothState(toothNumber: 18, condition: ToothCondition.healthy),
    17: const DentalToothState(toothNumber: 17, condition: ToothCondition.healthy),
    16: const DentalToothState(toothNumber: 16, condition: ToothCondition.caries, affectedSurfaces: ['O', 'M', 'D']),
    15: const DentalToothState(toothNumber: 15, condition: ToothCondition.healthy),
    14: const DentalToothState(toothNumber: 14, condition: ToothCondition.treated, affectedSurfaces: ['O']),
    13: const DentalToothState(toothNumber: 13, condition: ToothCondition.healthy),
    12: const DentalToothState(toothNumber: 12, condition: ToothCondition.healthy),
    11: const DentalToothState(toothNumber: 11, condition: ToothCondition.healthy),
    21: const DentalToothState(toothNumber: 21, condition: ToothCondition.healthy),
    22: const DentalToothState(toothNumber: 22, condition: ToothCondition.healthy),
    23: const DentalToothState(toothNumber: 23, condition: ToothCondition.healthy),
    24: const DentalToothState(toothNumber: 24, condition: ToothCondition.healthy),
    25: const DentalToothState(toothNumber: 25, condition: ToothCondition.healthy),
    26: const DentalToothState(toothNumber: 26, condition: ToothCondition.treated, affectedSurfaces: ['O', 'B']),
    27: const DentalToothState(toothNumber: 27, condition: ToothCondition.healthy),
    28: const DentalToothState(toothNumber: 28, condition: ToothCondition.healthy),
    48: const DentalToothState(toothNumber: 48, condition: ToothCondition.healthy),
    47: const DentalToothState(toothNumber: 47, condition: ToothCondition.caries, affectedSurfaces: ['O']),
    46: const DentalToothState(toothNumber: 46, condition: ToothCondition.healthy),
    45: const DentalToothState(toothNumber: 45, condition: ToothCondition.healthy),
    44: const DentalToothState(toothNumber: 44, condition: ToothCondition.healthy),
    43: const DentalToothState(toothNumber: 43, condition: ToothCondition.healthy),
    42: const DentalToothState(toothNumber: 42, condition: ToothCondition.healthy),
    41: const DentalToothState(toothNumber: 41, condition: ToothCondition.healthy),
    31: const DentalToothState(toothNumber: 31, condition: ToothCondition.healthy),
    32: const DentalToothState(toothNumber: 32, condition: ToothCondition.healthy),
    33: const DentalToothState(toothNumber: 33, condition: ToothCondition.healthy),
    34: const DentalToothState(toothNumber: 34, condition: ToothCondition.healthy),
    35: const DentalToothState(toothNumber: 35, condition: ToothCondition.healthy),
    36: const DentalToothState(toothNumber: 36, condition: ToothCondition.healthy),
    37: const DentalToothState(toothNumber: 37, condition: ToothCondition.healthy),
    38: const DentalToothState(toothNumber: 38, condition: ToothCondition.healthy),
  };

  final List<DentalProcedureLog> _dentalLogs = [
    DentalProcedureLog(
      id: 1,
      patientId: 88241,
      date: DateTime(2023, 10, 15),
      toothNumber: 16,
      procedureName: 'Restauración con Resina / Composite (MOD)',
      status: 'Pendiente',
      providerName: 'Dra. A. Smith',
      surfaces: ['M', 'O', 'D'],
    ),
    DentalProcedureLog(
      id: 2,
      patientId: 88241,
      date: DateTime(2023, 9, 2),
      toothNumber: 14,
      procedureName: 'Tratamiento de Conducto / Endodoncia',
      status: 'Completado',
      providerName: 'Dr. J. Doe',
      surfaces: ['O'],
    ),
    DentalProcedureLog(
      id: 3,
      patientId: 88241,
      date: DateTime(2022, 11, 20),
      toothNumber: 26,
      procedureName: 'Preparación y Colocación de Corona Dental',
      status: 'Completado',
      providerName: 'Dra. A. Smith',
      surfaces: ['O', 'B'],
    ),
  ];

  final List<GrowthRecord> _growthRecords = [
    GrowthRecord(
      id: 1,
      patientId: 8472,
      date: DateTime(2023, 10, 12),
      ageLabel: '2a 4m',
      ageMonths: 28,
      weightKg: 14.2,
      weightPercentile: 65,
      heightCm: 92.0,
      heightPercentile: 70,
      headCircumferenceCm: 49.0,
    ),
    GrowthRecord(
      id: 2,
      patientId: 8472,
      date: DateTime(2023, 6, 15),
      ageLabel: '2a',
      ageMonths: 24,
      weightKg: 12.5,
      weightPercentile: 55,
      heightCm: 87.0,
      heightPercentile: 60,
      headCircumferenceCm: 48.0,
    ),
    GrowthRecord(
      id: 3,
      patientId: 8472,
      date: DateTime(2022, 12, 10),
      ageLabel: '1a 6m',
      ageMonths: 18,
      weightKg: 11.1,
      weightPercentile: 50,
      heightCm: 82.0,
      heightPercentile: 50,
      headCircumferenceCm: 47.0,
    ),
    GrowthRecord(
      id: 4,
      patientId: 8472,
      date: DateTime(2022, 6, 14),
      ageLabel: '1a',
      ageMonths: 12,
      weightKg: 9.8,
      weightPercentile: 45,
      heightCm: 75.0,
      heightPercentile: 40,
      headCircumferenceCm: 46.0,
    ),
    GrowthRecord(
      id: 5,
      patientId: 8472,
      date: DateTime(2021, 12, 15),
      ageLabel: '6m',
      ageMonths: 6,
      weightKg: 7.9,
      weightPercentile: 50,
      heightCm: 67.0,
      heightPercentile: 45,
      headCircumferenceCm: 43.0,
    ),
    GrowthRecord(
      id: 6,
      patientId: 8472,
      date: DateTime(2021, 6, 15),
      ageLabel: 'Nacimiento',
      ageMonths: 0,
      weightKg: 3.4,
      weightPercentile: 50,
      heightCm: 50.0,
      heightPercentile: 50,
      headCircumferenceCm: 35.0,
    ),
  ];
}
