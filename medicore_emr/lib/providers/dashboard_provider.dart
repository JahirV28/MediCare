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

  bool get isLoading => _isLoading;
  int get appointmentsToday => _appointmentsToday;
  int get activePatients => _activePatients;
  double get dailyIncome => _dailyIncome;
  List<double> get weeklyActivity => _weeklyActivity;
  List<Appointment> get upcomingAppointments => _upcomingAppointments;

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getTodayAppointments(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      _appointmentsToday = stats['appointments_today'] as int;
      _activePatients = stats['active_patients'] as int;
      _dailyIncome = (stats['daily_income'] as num).toDouble();
      _weeklyActivity = (stats['weekly_activity'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      _upcomingAppointments = results[1] as List<Appointment>;
    } catch (e) {
      // Handle error silently for mock
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
      _appointmentsToday = stats['appointments_today'] as int;
      _activePatients = stats['active_patients'] as int;
      _dailyIncome = (stats['daily_income'] as num).toDouble();
      _weeklyActivity = (stats['weekly_activity'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      _upcomingAppointments = results[1] as List<Appointment>;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateAppointmentStatus(int appointmentId, String newStatus) async {
    await _api.updateAppointmentStatus(appointmentId, newStatus);
    await refreshSilently();
  }

  Future<void> recordIncome(double amount, {int? patientId, int? appointmentId, String? concept}) async {
    await _api.addIncome(amount, patientId: patientId, appointmentId: appointmentId, concept: concept);
    await refreshSilently();
  }

  Future<void> addAppointment(Appointment appointment) async {
    await _api.addAppointment(appointment);
    await refreshSilently();
  }
}
