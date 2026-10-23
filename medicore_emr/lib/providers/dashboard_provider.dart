import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../services/supabase_service.dart';

class DashboardProvider extends ChangeNotifier {
  final SupabaseService _api = SupabaseService();

  bool _isLoading = false;
  int _appointmentsToday = 0;
  int _activePatients = 0;
  double _dailyIncome = 0;
  List<double> _weeklyActivity = [];
  List<Appointment> _upcomingAppointments = [];
  int _todayIndex = (DateTime.now().weekday - 1).clamp(0, 5);

  bool get isLoading => _isLoading;
  int get appointmentsToday => _appointmentsToday;
  int get activePatients => _activePatients;
  double get dailyIncome => _dailyIncome;
  List<double> get weeklyActivity => _weeklyActivity;
  List<Appointment> get upcomingAppointments => _upcomingAppointments;
  int get todayIndex => _todayIndex;

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getTodayAppointments(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      _appointmentsToday = (stats['appointments_today'] as num?)?.toInt() ?? 0;
      _activePatients = (stats['active_patients'] as num?)?.toInt() ?? 0;
      _dailyIncome = (stats['daily_income'] as num?)?.toDouble() ?? 0.0;
      _weeklyActivity = (stats['weekly_activity'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0, 0, 0, 0, 0, 0];
      if (stats['today_index'] != null) {
        _todayIndex = (stats['today_index'] as num).toInt().clamp(0, 5);
      } else {
        _todayIndex = (DateTime.now().weekday - 1).clamp(0, 5);
      }

      _upcomingAppointments = results[1] as List<Appointment>;
    } catch (e) {
      debugPrint('Error al cargar dashboard: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshSilently() async {
    try {
      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getTodayAppointments(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      _appointmentsToday = (stats['appointments_today'] as num?)?.toInt() ?? 0;
      _activePatients = (stats['active_patients'] as num?)?.toInt() ?? 0;
      _dailyIncome = (stats['daily_income'] as num?)?.toDouble() ?? 0.0;
      _weeklyActivity = (stats['weekly_activity'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0, 0, 0, 0, 0, 0];
      if (stats['today_index'] != null) {
        _todayIndex = (stats['today_index'] as num).toInt().clamp(0, 5);
      }

      _upcomingAppointments = results[1] as List<Appointment>;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateAppointmentStatus(int appointmentId, String newStatus) async {
    final success = await _api.updateAppointmentStatus(appointmentId, newStatus);
    await refreshSilently();
    return success;
  }

  Future<bool> recordIncome(double amount, {int? patientId, int? appointmentId, String? concept}) async {
    final success = await _api.addIncome(amount, patientId: patientId, appointmentId: appointmentId, concept: concept);
    await refreshSilently();
    return success;
  }

  Future<bool> addAppointment(Appointment appointment) async {
    final success = await _api.addAppointment(appointment);
    await refreshSilently();
    return success;
  }
}
