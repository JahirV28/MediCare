import 'package:flutter/material.dart';
import '../models/soap_consultation.dart';
import '../models/prescription.dart';
import '../models/diagnostic_file.dart';
import '../models/odontogram_finding.dart';
import '../models/growth_record.dart';
import '../services/supabase_service.dart';

// ─── CONSULTATION PROVIDER ───
class ConsultationProvider extends ChangeNotifier {
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  SoapConsultation? _currentConsultation;
  VitalSigns _vitalSigns = VitalSigns();

  bool get isLoading => _isLoading;
  SoapConsultation? get currentConsultation => _currentConsultation;
  VitalSigns get vitalSigns => _vitalSigns;

  Future<void> loadConsultation(String patientName, String patientCode, {int? patientId}) async {
    _isLoading = true;
    notifyListeners();

    _currentConsultation = await _api.getInitialSoapConsultation(
      patientName,
      patientCode,
      patientId: patientId,
    );
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
    int? patientId,
    String? patientName,
    String? patientCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final targetPatientId = patientId ?? _currentConsultation?.patientId ?? 1;
    final targetPatientName = patientName ?? _currentConsultation?.patientName ?? 'Paciente';
    final targetPatientCode = patientCode ?? _currentConsultation?.patientCode ?? 'PT-000';

    final updated = SoapConsultation(
      id: _currentConsultation?.id,
      patientId: targetPatientId,
      doctorId: 1,
      date: DateTime.now(),
      patientName: targetPatientName,
      patientCode: targetPatientCode,
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
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  Prescription? _prescription;

  bool get isLoading => _isLoading;
  Prescription? get prescription => _prescription;
  List<PrescriptionItem> get items => _prescription?.items ?? [];

  Future<void> loadPrescription({int? patientId}) async {
    _isLoading = true;
    notifyListeners();

    _prescription = await _api.getActivePrescription(patientId: patientId);

    _isLoading = false;
    notifyListeners();
  }

  void addItem(PrescriptionItem item) {
    if (_prescription == null) return;
    final updatedList = List<PrescriptionItem>.from(_prescription!.items)
      ..add(item);
    _prescription = _prescription!.copyWith(items: updatedList);
    notifyListeners();
  }

  void removeItem(int index) {
    if (_prescription == null) return;
    final updatedList = List<PrescriptionItem>.from(_prescription!.items)
      ..removeAt(index);
    _prescription = _prescription!.copyWith(items: updatedList);
    notifyListeners();
  }

  Future<bool> savePrescription(int patientId) async {
    if (_prescription == null) return false;
    _isLoading = true;
    notifyListeners();

    final success = await _api.savePrescription(
      patientId: patientId,
      items: _prescription!.items,
    );
    _isLoading = false;
    notifyListeners();
    return success;
  }
}

// ─── DIAGNOSTIC PROVIDER ───
class DiagnosticProvider extends ChangeNotifier {
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  List<DiagnosticFile> _files = [];
  DiagnosticFile? _selectedFile;
  String _selectedCategory = 'All Categories';
  int? _currentPatientId;

  bool get isLoading => _isLoading;
  int? get currentPatientId => _currentPatientId;
  List<DiagnosticFile> get files {
    if (_selectedCategory == 'All Categories') return _files;
    return _files.where((f) => f.category == _selectedCategory).toList();
  }

  DiagnosticFile? get selectedFile => _selectedFile;
  String get selectedCategory => _selectedCategory;

  Future<void> loadFiles(int patientId) async {
    _isLoading = true;
    _currentPatientId = patientId;
    notifyListeners();

    _files = await _api.getDiagnosticFiles(patientId);
    if (_files.isNotEmpty && _selectedFile == null) {
      _selectedFile = _files.length > 1
          ? _files[1]
          : _files.first; // Default to Blood Panel
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

  Future<bool> uploadFile(DiagnosticFile file, {int? patientId}) async {
    _files.insert(0, file);
    _selectedFile = file;
    notifyListeners();

    final targetPatientId = patientId ?? _currentPatientId ?? file.patientId;
    if (targetPatientId > 0) {
      final ok = await _api.uploadDiagnosticFile(
        patientId: targetPatientId,
        fileName: file.fileName,
        category: file.category,
        fileUrl: file.fileUrl,
        fileSize: file.fileSize,
        totalPages: file.totalPages,
        mimeType: file.mimeType,
      );
      return ok;
    }
    return true;
  }
}

// ─── ODONTOLOGY PROVIDER ───
class OdontologyProvider extends ChangeNotifier {
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  Map<int, DentalToothState> _teethState = {};
  List<DentalProcedureLog> _logs = [];
  DmftSummary _dmft = const DmftSummary(decayed: 0, missing: 0, filled: 0);
  int _selectedTooth = 18;
  final Set<String> _selectedSurfaces = {};
  String _selectedCondition = 'Sano';
  int? _currentPatientId;

  bool get isLoading => _isLoading;
  Map<int, DentalToothState> get teethState => _teethState;
  List<DentalProcedureLog> get logs => _logs;
  DmftSummary get dmft => _dmft;
  int get selectedTooth => _selectedTooth;
  Set<String> get selectedSurfaces => _selectedSurfaces;
  String get selectedCondition => _selectedCondition;
  int? get currentPatientId => _currentPatientId;

  void clear() {
    _currentPatientId = null;
    _teethState = {};
    _logs = [];
    _dmft = const DmftSummary(decayed: 0, missing: 0, filled: 0);
    _selectedTooth = 18;
    _selectedSurfaces.clear();
    _selectedCondition = 'Sano';
    notifyListeners();
  }

  Future<void> loadOdontologyData(int? patientId) async {
    if (patientId == null || patientId <= 0) {
      clear();
      return;
    }

    _isLoading = true;
    _currentPatientId = patientId;
    notifyListeners();

    try {
      _teethState = await _api.getOdontogramState(patientId);
      _logs = await _api.getDentalProcedureLogs(patientId);
      _recalculateDmft();
    } catch (e) {
      debugPrint('Error cargando datos de odontología: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectTooth(int tooth) {
    _selectedTooth = tooth;
    final current = _teethState[tooth];
    _selectedSurfaces.clear();
    if (current != null) {
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
    } else {
      _selectedCondition = 'Sano';
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

  Future<bool> addFinding({
    required String procedureName,
    int? toothNumber,
    ToothCondition? condition,
    List<String>? surfaces,
    String? notes,
    double? cost,
    String? anesthesia,
    String status = 'Pendiente',
    int? patientId,
  }) async {
    final pId = patientId ?? _currentPatientId;
    if (pId == null || pId <= 0) return false;

    final tooth = toothNumber ?? _selectedTooth;
    final surf = surfaces ?? _selectedSurfaces.toList();

    ToothCondition resolvedCondition;
    if (condition != null) {
      resolvedCondition = condition;
    } else {
      final condLower = _selectedCondition.toLowerCase();
      if (condLower.contains('caries')) {
        resolvedCondition = ToothCondition.caries;
      } else if (condLower.contains('tratado') ||
          condLower.contains('restor') ||
          condLower.contains('treated') ||
          condLower.contains('corona') ||
          condLower.contains('obtur')) {
        resolvedCondition = ToothCondition.treated;
      } else if (condLower.contains('ausente') ||
          condLower.contains('extrac') ||
          condLower.contains('missing') ||
          condLower.contains('perdid')) {
        resolvedCondition = ToothCondition.missing;
      } else {
        resolvedCondition = ToothCondition.healthy;
      }
    }

    // Actualización optimista inmediata
    _teethState[tooth] = DentalToothState(
      toothNumber: tooth,
      condition: resolvedCondition,
      affectedSurfaces: surf,
      activeProcedure: procedureName,
    );

    _logs.insert(
      0,
      DentalProcedureLog(
        patientId: pId,
        date: DateTime.now(),
        toothNumber: tooth,
        procedureName: procedureName.isNotEmpty ? procedureName : 'Evaluación Dental',
        status: status,
        providerName: 'Dr. Odontólogo',
        notes: notes,
        surfaces: surf,
        cost: cost,
        condition: _selectedCondition,
        anesthesia: anesthesia,
      ),
    );

    _recalculateDmft();
    notifyListeners();

    // Guardado persistente en Supabase
    final success = await _api.saveOdontogramFinding(
      patientId: pId,
      toothNumber: tooth,
      condition: resolvedCondition,
      surfaces: surf,
      procedureName: procedureName.isNotEmpty ? procedureName : 'Evaluación Dental',
      status: status,
      notes: notes,
      cost: cost,
      anesthesia: anesthesia,
    );

    // Recargar para sincronizar IDs reales de Supabase
    await loadOdontologyData(pId);
    return success;
  }

  Future<bool> updateProcedureStatus(int logId, String newStatus) async {
    final success = await _api.updateOdontogramStatus(logId, newStatus);
    if (success && _currentPatientId != null) {
      await loadOdontologyData(_currentPatientId!);
    }
    return success;
  }

  Future<bool> updateFinding({
    required int logId,
    required int toothNumber,
    required ToothCondition condition,
    required List<String> surfaces,
    required String procedureName,
    required String status,
    String? notes,
    double? cost,
    String? anesthesia,
  }) async {
    final success = await _api.updateOdontogramFinding(
      findingId: logId,
      toothNumber: toothNumber,
      condition: condition,
      surfaces: surfaces,
      procedureName: procedureName,
      status: status,
      notes: notes,
      cost: cost,
      anesthesia: anesthesia,
    );
    if (success && _currentPatientId != null) {
      await loadOdontologyData(_currentPatientId!);
    }
    return success;
  }

  Future<bool> deleteFinding(int logId) async {
    final success = await _api.deleteOdontogramFinding(logId);
    if (success && _currentPatientId != null) {
      await loadOdontologyData(_currentPatientId!);
    }
    return success;
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
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  List<GrowthRecord> _records = [];
  String _selectedMetric = 'Peso para la edad (0-5 años)';
  int? _currentPatientId;

  bool get isLoading => _isLoading;
  List<GrowthRecord> get records => _records;
  String get selectedMetric => _selectedMetric;
  int? get currentPatientId => _currentPatientId;

  Future<void> loadGrowthData(int patientId) async {
    _isLoading = true;
    _currentPatientId = patientId;
    notifyListeners();

    _records = await _api.getPediatricGrowthHistory(patientId);

    _isLoading = false;
    notifyListeners();
  }

  void setMetric(String metric) {
    _selectedMetric = metric;
    notifyListeners();
  }

  Future<bool> addRecord(GrowthRecord record, {int? patientId}) async {
    _records.insert(0, record);
    // Ordenar de más reciente a más antiguo
    _records.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    final targetPatientId = patientId ?? _currentPatientId;
    if (targetPatientId != null && targetPatientId > 0) {
      final ok = await _api.savePediatricGrowthRecord(
        patientId: targetPatientId,
        date: record.date,
        ageLabel: record.ageLabel,
        ageMonths: record.ageMonths,
        weightKg: record.weightKg,
        heightCm: record.heightCm,
        headCircumferenceCm: record.headCircumferenceCm,
        weightPercentile: record.weightPercentile,
        heightPercentile: record.heightPercentile,
        notes: null,
      );
      return ok;
    }
    return true;
  }
}
