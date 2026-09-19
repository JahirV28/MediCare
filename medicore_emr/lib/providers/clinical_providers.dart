import 'package:flutter/material.dart';
import '../models/soap_consultation.dart';
import '../models/prescription.dart';
import '../models/diagnostic_file.dart';
import '../models/odontogram_finding.dart';
import '../models/growth_record.dart';
import '../services/mock_api_service.dart';

// ─── CONSULTATION PROVIDER ───
class ConsultationProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  SoapConsultation? _currentConsultation;
  VitalSigns _vitalSigns = VitalSigns();

  bool get isLoading => _isLoading;
  SoapConsultation? get currentConsultation => _currentConsultation;
  VitalSigns get vitalSigns => _vitalSigns;

  Future<void> loadConsultation(String patientName, String patientCode) async {
    _isLoading = true;
    notifyListeners();

    _currentConsultation = await _api.getInitialSoapConsultation(patientName, patientCode);
    if (_currentConsultation != null) {
      _vitalSigns = _currentConsultation!.vitalSigns;
    }

    _isLoading = false;
    notifyListeners();
  }

  void updateVitals({
    int? bpSystolic,
    int? bpDiastolic,
    int? pulse,
    double? temperature,
    double? weightKg,
    double? heightCm,
  }) {
    _vitalSigns = _vitalSigns.copyWith(
      bpSystolic: bpSystolic,
      bpDiastolic: bpDiastolic,
      pulse: pulse,
      temperature: temperature,
      weightKg: weightKg,
      heightCm: heightCm,
    );
    notifyListeners();
  }

  Future<bool> saveConsultation({
    required String subjective,
    required String objective,
    required String icd10Code,
    required String assessment,
    required String plan,
    bool isFinalized = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    final updated = SoapConsultation(
      patientId: _currentConsultation?.patientId ?? 987654,
      doctorId: 1,
      date: DateTime.now(),
      patientName: _currentConsultation?.patientName ?? 'Juan Perez',
      patientCode: _currentConsultation?.patientCode ?? '987654',
      vitalSigns: _vitalSigns,
      subjective: subjective,
      objective: objective,
      icd10Code: icd10Code,
      assessment: assessment,
      plan: plan,
      status: isFinalized ? 'Finalized' : 'Draft',
    );

    final success = await _api.saveSoapConsultation(updated);
    _currentConsultation = updated;
    _isLoading = false;
    notifyListeners();
    return success;
  }
}

// ─── PRESCRIPTION PROVIDER ───
class PrescriptionProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  Prescription? _prescription;

  bool get isLoading => _isLoading;
  Prescription? get prescription => _prescription;
  List<PrescriptionItem> get items => _prescription?.items ?? [];

  Future<void> loadPrescription() async {
    _isLoading = true;
    notifyListeners();

    _prescription = await _api.getActivePrescription();

    _isLoading = false;
    notifyListeners();
  }

  void addItem(PrescriptionItem item) {
    if (_prescription == null) return;
    final updatedList = List<PrescriptionItem>.from(_prescription!.items)..add(item);
    _prescription = _prescription!.copyWith(items: updatedList);
    notifyListeners();
  }

  void removeItem(int index) {
    if (_prescription == null) return;
    final updatedList = List<PrescriptionItem>.from(_prescription!.items)..removeAt(index);
    _prescription = _prescription!.copyWith(items: updatedList);
    notifyListeners();
  }
}

// ─── DIAGNOSTIC PROVIDER ───
class DiagnosticProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  List<DiagnosticFile> _files = [];
  DiagnosticFile? _selectedFile;
  String _selectedCategory = 'All Categories';

  bool get isLoading => _isLoading;
  List<DiagnosticFile> get files {
    if (_selectedCategory == 'All Categories') return _files;
    return _files.where((f) => f.category == _selectedCategory).toList();
  }
  DiagnosticFile? get selectedFile => _selectedFile;
  String get selectedCategory => _selectedCategory;

  Future<void> loadFiles(int patientId) async {
    _isLoading = true;
    notifyListeners();

    _files = await _api.getDiagnosticFiles(patientId);
    if (_files.isNotEmpty && _selectedFile == null) {
      _selectedFile = _files.length > 1 ? _files[1] : _files.first; // Default to Blood Panel
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectFile(DiagnosticFile file) {
    _selectedFile = file;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void uploadFile(DiagnosticFile file) {
    _files.insert(0, file);
    _selectedFile = file;
    notifyListeners();
  }
}

// ─── ODONTOLOGY PROVIDER ───
class OdontologyProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  Map<int, DentalToothState> _teethState = {};
  List<DentalProcedureLog> _logs = [];
  DmftSummary _dmft = const DmftSummary(decayed: 2, missing: 0, filled: 2);
  int _selectedTooth = 16;
  final Set<String> _selectedSurfaces = {'O'};
  String _selectedCondition = 'Caries';

  bool get isLoading => _isLoading;
  Map<int, DentalToothState> get teethState => _teethState;
  List<DentalProcedureLog> get logs => _logs;
  DmftSummary get dmft => _dmft;
  int get selectedTooth => _selectedTooth;
  Set<String> get selectedSurfaces => _selectedSurfaces;
  String get selectedCondition => _selectedCondition;

  Future<void> loadOdontologyData(int patientId) async {
    _isLoading = true;
    notifyListeners();

    _teethState = await _api.getOdontogramState(patientId);
    _logs = await _api.getDentalProcedureLogs(patientId);
    _recalculateDmft();

    _isLoading = false;
    notifyListeners();
  }

  void selectTooth(int tooth) {
    _selectedTooth = tooth;
    final current = _teethState[tooth];
    if (current != null) {
      _selectedSurfaces.clear();
      _selectedSurfaces.addAll(current.affectedSurfaces);
      switch (current.condition) {
        case ToothCondition.caries:
          _selectedCondition = 'Caries';
          break;
        case ToothCondition.treated:
          _selectedCondition = 'Tratado / Restaurado';
          break;
        case ToothCondition.missing:
          _selectedCondition = 'Ausente / Extracción';
          break;
        case ToothCondition.healthy:
          _selectedCondition = 'Sano';
          break;
      }
    }
    notifyListeners();
  }

  void toggleSurface(String surface) {
    if (_selectedSurfaces.contains(surface)) {
      _selectedSurfaces.remove(surface);
    } else {
      _selectedSurfaces.add(surface);
    }
    notifyListeners();
  }

  void setCondition(String condition) {
    _selectedCondition = condition;
    notifyListeners();
  }

  void addFinding({required String procedureName, String? notes}) {
    ToothCondition condition;
    final condLower = _selectedCondition.toLowerCase();
    if (condLower.contains('caries')) {
      condition = ToothCondition.caries;
    } else if (condLower.contains('tratado') || condLower.contains('restor') || condLower.contains('treated')) {
      condition = ToothCondition.treated;
    } else if (condLower.contains('ausente') || condLower.contains('extrac') || condLower.contains('missing')) {
      condition = ToothCondition.missing;
    } else {
      condition = ToothCondition.healthy;
    }

    _teethState[_selectedTooth] = DentalToothState(
      toothNumber: _selectedTooth,
      condition: condition,
      affectedSurfaces: _selectedSurfaces.toList(),
      activeProcedure: procedureName,
    );

    _logs.insert(
      0,
      DentalProcedureLog(
        patientId: 88241,
        date: DateTime.now(),
        toothNumber: _selectedTooth,
        procedureName: procedureName.isNotEmpty ? procedureName : 'Evaluación y Diagnóstico',
        status: 'Pendiente',
        providerName: 'Dra. A. Smith',
        notes: notes,
        surfaces: _selectedSurfaces.toList(),
      ),
    );

    _recalculateDmft();
    notifyListeners();
  }

  void _recalculateDmft() {
    int decayed = 0;
    int missing = 0;
    int filled = 0;
    for (final tooth in _teethState.values) {
      if (tooth.condition == ToothCondition.caries) decayed++;
      if (tooth.condition == ToothCondition.missing) missing++;
      if (tooth.condition == ToothCondition.treated) filled++;
    }
    _dmft = DmftSummary(decayed: decayed, missing: missing, filled: filled);
  }
}

// ─── PEDIATRICS PROVIDER ───
class PediatricsProvider extends ChangeNotifier {
  final MockApiService _api = MockApiService();

  bool _isLoading = false;
  List<GrowthRecord> _records = [];
  String _selectedMetric = 'Peso para la edad (0-5 años)';

  bool get isLoading => _isLoading;
  List<GrowthRecord> get records => _records;
  String get selectedMetric => _selectedMetric;

  Future<void> loadGrowthData(int patientId) async {
    _isLoading = true;
    notifyListeners();

    _records = await _api.getPediatricGrowthHistory(patientId);

    _isLoading = false;
    notifyListeners();
  }

  void setMetric(String metric) {
    _selectedMetric = metric;
    notifyListeners();
  }

  void addRecord(GrowthRecord record) {
    _records.insert(0, record);
    // Ordenar de más reciente a más antiguo
    _records.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }
}
