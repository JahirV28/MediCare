import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/patient_provider.dart';
import '../widgets/sidebar/sidebar_widget.dart';
import '../widgets/top_bar/top_bar_widget.dart';
import 'dashboard/dashboard_screen.dart';
import 'patients/patients_directory_screen.dart';
import 'patients/patient_registration_screen.dart';
import 'patients/patient_detail_screen.dart';
import 'consultation/new_consultation_screen.dart';
import 'prescription/prescription_builder_screen.dart';
import 'diagnostics/diagnostic_files_screen.dart';
import 'odontology/odontology_screen.dart';
import 'pediatrics/pediatrics_growth_screen.dart';
import 'calendar/calendar_screen.dart';
import 'finances/finances_screen.dart';
import 'backups/backups_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  final String? subRoute;

  const MainLayout({
    super.key,
    this.initialIndex = 0,
    this.subRoute,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  String? _currentSubRoute;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _currentSubRoute = widget.subRoute;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          SidebarWidget(
            selectedIndex: _showSettings ? -1 : _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _currentSubRoute = null;
                _showSettings = false;
              });
            },
            onSettingsTap: () {
              setState(() {
                _showSettings = true;
              });
            },
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                const TopBarWidget(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_showSettings) {
      return SettingsScreen(
        onBack: () => setState(() {
          _showSettings = false;
          _selectedIndex = 0;
        }),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          onNavigateToPatients: () {
            setState(() {
              _selectedIndex = 1;
              _currentSubRoute = null;
            });
          },
          onNavigateToNewPatient: () {
            setState(() {
              _selectedIndex = 1;
              _currentSubRoute = 'registration';
            });
          },
          onNavigateToNewConsultation: () {
            setState(() {
              _selectedIndex = 1;
              _currentSubRoute = 'consultation';
            });
          },
          onNavigateToCalendar: () {
            setState(() {
              _selectedIndex = 2;
              _currentSubRoute = null;
            });
          },
          onNavigateToPatientDetail: (patientId) async {
            await context.read<PatientProvider>().selectPatientById(patientId);
            if (mounted) {
              setState(() {
                _selectedIndex = 1;
                _currentSubRoute = 'detail';
              });
            }
          },
          onNavigateToConsultation: (patientId) async {
            await context.read<PatientProvider>().selectPatientById(patientId);
            if (mounted) {
              setState(() {
                _selectedIndex = 1;
                _currentSubRoute = 'consultation';
              });
            }
          },
        );
      case 1:
        return _buildPatientsContent();
      case 2:
        return CalendarScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 3:
        return OdontologyScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 4:
        return PediatricsGrowthScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 5:
        return FinancesScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 6:
        return BackupsScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      case 7:
        return ReportsScreen(
          onBack: () => setState(() => _selectedIndex = 0),
        );
      default:
        return _placeholderScreen('Próximamente', Icons.construction);
    }
  }

  Widget _buildPatientsContent() {
    switch (_currentSubRoute) {
      case 'registration':
        return PatientRegistrationScreen(
          onCancel: () => setState(() => _currentSubRoute = null),
          onSaved: () => setState(() => _currentSubRoute = null),
        );
      case 'detail':
        return PatientDetailScreen(
          onBack: () => setState(() => _currentSubRoute = null),
          onNavigateToConsultation: () => setState(() => _currentSubRoute = 'consultation'),
          onNavigateToPrescription: () => setState(() => _currentSubRoute = 'prescription'),
          onNavigateToDiagnostics: () => setState(() => _currentSubRoute = 'diagnostics'),
        );
      case 'consultation':
        return NewConsultationScreen(
          onBack: () => setState(() => _currentSubRoute = 'detail'),
          onSaved: () => setState(() => _currentSubRoute = 'detail'),
        );
      case 'prescription':
        return PrescriptionBuilderScreen(
          onBack: () => setState(() => _currentSubRoute = 'detail'),
        );
      case 'diagnostics':
        return DiagnosticFilesScreen(
          onBack: () => setState(() => _currentSubRoute = 'detail'),
        );
      default:
        return PatientsDirectoryScreen(
          onNavigateToNewPatient: () => setState(() => _currentSubRoute = 'registration'),
          onNavigateToDetail: () => setState(() => _currentSubRoute = 'detail'),
        );
    }
  }

  Widget _placeholderScreen(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 40, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta sección estará disponible próximamente.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
