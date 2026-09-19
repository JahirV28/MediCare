import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/clinical_record.dart';
import '../models/allergy_alert.dart';
import '../models/emergency_contact.dart';
import '../services/mock_api_service.dart';

class PatientProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  List<Patient> _patients = [];
  Patient? _selectedPatient;
  List<ClinicalRecord> _clinicalRecords = [];
  List<AllergyAlert> _allergyAlerts = [];
  List<EmergencyContact> _emergencyContacts = [];
  int _totalPatients = 0;
  int _currentPage = 1;
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  List<Patient> get patients => _patients;
  Patient? get selectedPatient => _selectedPatient;
  List<ClinicalRecord> get clinicalRecords => _clinicalRecords;
  List<AllergyAlert> get allergyAlerts => _allergyAlerts;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  int get totalPatients => _totalPatients;
  int get currentPage => _currentPage;
  String get searchQuery => _searchQuery;

  Future<void> loadPatients({String? search}) async {
    _isLoading = true;
    _searchQuery = search ?? '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getPatients(search: _searchQuery, page: _currentPage),
        _api.getPatientsCount(search: _searchQuery),
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
    loadPatients(search: _searchQuery);
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
    _isLoading = true;
    notifyListeners();

    try {
      final patient = await _api.getPatientByIdOrName(patientId, patientName);
      if (patient != null) {
        _selectedPatient = patient;
        final results = await Future.wait([
          _api.getClinicalRecords(patient.id ?? patientId),
          _api.getAllergyAlerts(patient.id ?? patientId),
          _api.getEmergencyContacts(patient.id ?? patientId),
        ]);
        _clinicalRecords = results[0] as List<ClinicalRecord>;
        _allergyAlerts = results[1] as List<AllergyAlert>;
        _emergencyContacts = results[2] as List<EmergencyContact>;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> togglePatientStatus(int patientId) async {
    final success = await _api.togglePatientActiveStatus(patientId);
    if (success) {
      if (_selectedPatient != null && _selectedPatient!.id == patientId) {
        _selectedPatient = _selectedPatient!.copyWith(isActive: !_selectedPatient!.isActive);
      }
      await loadPatients(search: _searchQuery);
    }
    return success;
  }
}

