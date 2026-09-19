import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/patient.dart';
import '../../providers/patient_provider.dart';
import '../../providers/dashboard_provider.dart';

class PatientInfoCard extends StatelessWidget {
  final Patient patient;

  const PatientInfoCard({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Profile Photo
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Center(
                  child: Text(
                    patient.initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: patient.isActive ? AppColors.success : AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  patient.isActive ? Icons.check : Icons.pause,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            patient.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${patient.patientCode}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Info grid
          Row(
            children: [
              Expanded(
                child: _infoItem('EDAD', '${patient.age ?? "-"} Años'),
              ),
              Expanded(
                child: _infoItem('SEXO', patient.gender ?? '-'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  'SANGRE',
                  patient.bloodType ?? '-',
                  valueColor: AppColors.danger,
                ),
              ),
              Expanded(
                child: _infoItem('NACIMIENTO', _formatDate(patient.birthDate)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // Contact section
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CONTACTO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _contactRow(Icons.phone_outlined, patient.phone ?? '-'),
          const SizedBox(height: 8),
          _contactRow(Icons.email_outlined, patient.email ?? '-'),
          const SizedBox(height: 8),
          _contactRow(Icons.home_outlined, patient.address ?? '-'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Toggle Active Status
          InkWell(
            onTap: () async {
              if (patient.id != null) {
                final newStatus = !patient.isActive;
                final messenger = ScaffoldMessenger.of(context);
                final dashboard = context.read<DashboardProvider>();
                await context.read<PatientProvider>().togglePatientStatus(patient.id!);
                await dashboard.loadDashboard();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(newStatus
                        ? 'Paciente "${patient.fullName}" activado exitosamente.'
                        : 'Paciente "${patient.fullName}" desactivado.'),
                    backgroundColor: newStatus ? AppColors.success : AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: patient.isActive ? AppColors.successLight : AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: patient.isActive ? AppColors.success : AppColors.danger,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    patient.isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                    size: 16,
                    color: patient.isActive ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    patient.isActive ? 'Estado: ACTIVO' : 'Estado: INACTIVO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: patient.isActive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: patient.isActive ? AppColors.success : AppColors.danger,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
