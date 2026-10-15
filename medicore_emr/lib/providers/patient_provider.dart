import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/clinical_record.dart';
import '../models/allergy_alert.dart';
import '../models/emergency_contact.dart';
import '../services/supabase_service.dart';

class PatientProvider extends ChangeNotifier {
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  List<Patient> _patients = [];
  Patient? _selectedPatient;
  List<ClinicalRecord> _clinicalRecords = [];
  List<AllergyAlert> _allergyAlerts = [];
  List<EmergencyContact> _emergencyContacts = [];
  int _totalPatients = 0;
  int _currentPage = 1;
  String _searchQuery = '';
  String _statusFilter = 'Todos';

  bool get isLoading => _isLoading;
  List<Patient> get patients => _patients;
  Patient? get selectedPatient => _selectedPatient;
  List<ClinicalRecord> get clinicalRecords => _clinicalRecords;
  List<AllergyAlert> get allergyAlerts => _allergyAlerts;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  int get totalPatients => _totalPatients;
  int get currentPage => _currentPage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;

  Future<void> loadPatients({String? search, String? statusFilter}) async {
    _isLoading = true;
    if (search != null) _searchQuery = search;
    if (statusFilter != null) _statusFilter = statusFilter;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getPatients(
          search: _searchQuery,
          statusFilter: _statusFilter,
          page: _currentPage,
        ),
        _api.getPatientsCount(
          search: _searchQuery,
          statusFilter: _statusFilter,
        ),
      ]);
      _patients = results[0] as List<Patient>;
      _totalPatients = results[1] as int;
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    loadPatients(search: _searchQuery, statusFilter: _statusFilter);
  }

  Future<void> loadPatientDetail() async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedPatient ??= await _api.getPatientDetail();
      if (_selectedPatient != null && _selectedPatient!.id != null) {
        final results = await Future.wait([
          _api.getClinicalRecords(_selectedPatient!.id!),
          _api.getAllergyAlerts(_selectedPatient!.id!),
          _api.getEmergencyContacts(_selectedPatient!.id!),
        ]);
        _clinicalRecords = results[0] as List<ClinicalRecord>;
        _allergyAlerts = results[1] as List<AllergyAlert>;
        _emergencyContacts = results[2] as List<EmergencyContact>;
      }
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectPatient(Patient patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  Future<bool> createPatient(Patient patient, {EmergencyContact? emergencyContact}) async {
    _isLoading = true;
    notifyListeners();

    final success = await _api.createPatient(patient, emergencyContact: emergencyContact);

    if (success) {
      _currentPage = 1;
      _searchQuery = '';
      await loadPatients();
    } else {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<void> selectPatientById(int patientId, {String? patientName}) async {
    await selectPatientByNameOrId(patientId: patientId, patientName: patientName);
  }

  Future<void> selectPatientByNameOrId({int? patientId, String? patientName}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final patient = await _api.getPatientDetail(
        patientId: patientId,
        patientName: patientName,
      );
      _selectedPatient = patient;
      final realId = patient.id ?? patientId ?? 1;
      final results = await Future.wait([
        _api.getClinicalRecords(realId),
        _api.getAllergyAlerts(realId),
        _api.getEmergencyContacts(realId),
      ]);
      _clinicalRecords = results[0] as List<ClinicalRecord>;
      _allergyAlerts = results[1] as List<AllergyAlert>;
      _emergencyContacts = results[2] as List<EmergencyContact>;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Patient>> searchPatients(String query) async {
    return _api.searchPatients(query);
  }

  Future<bool> togglePatientStatus(int patientId) async {
    final currentActive = _selectedPatient != null && _selectedPatient!.id == patientId
        ? _selectedPatient!.isActive
        : true;
    final success = await _api.togglePatientActiveStatus(patientId, currentActive);
    if (success) {
      if (_selectedPatient != null && _selectedPatient!.id == patientId) {
        _selectedPatient = _selectedPatient!.copyWith(isActive: !currentActive);
      }
      await loadPatients(search: _searchQuery, statusFilter: _statusFilter);
    }
    return success;
  }
}

