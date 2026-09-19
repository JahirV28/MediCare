import 'package:flutter/material.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/register/register_screen.dart';
import '../../screens/main_layout.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String patients = '/patients';
  static const String patientRegistration = '/patients/new';
  static const String patientDetail = '/patients/detail';
  static const String consultation = '/consultation';
  static const String prescription = '/prescription';
  static const String diagnostics = '/diagnostics';
  static const String odontology = '/odontology';
  static const String pediatrics = '/pediatrics';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    dashboard: (context) => const MainLayout(initialIndex: 0),
    patients: (context) => const MainLayout(initialIndex: 1),
    patientRegistration: (context) => const MainLayout(initialIndex: 1, subRoute: 'registration'),
    patientDetail: (context) => const MainLayout(initialIndex: 1, subRoute: 'detail'),
    consultation: (context) => const MainLayout(initialIndex: 1, subRoute: 'consultation'),
    prescription: (context) => const MainLayout(initialIndex: 1, subRoute: 'prescription'),
    diagnostics: (context) => const MainLayout(initialIndex: 1, subRoute: 'diagnostics'),
    odontology: (context) => const MainLayout(initialIndex: 3),
    pediatrics: (context) => const MainLayout(initialIndex: 4),
  };
}
