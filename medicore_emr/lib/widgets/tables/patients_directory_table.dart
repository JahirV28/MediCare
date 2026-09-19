import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/patient.dart';
import '../common/avatar_circle.dart';

class PatientsDirectoryTable extends StatelessWidget {
  final List<Patient> patients;
  final int totalPatients;
  final int currentPage;
  final Function(int) onPageChanged;
  final Function(Patient) onPatientTap;

  const PatientsDirectoryTable({
    super.key,
    required this.patients,
    required this.totalPatients,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = totalPatients <= 0 ? 1 : (totalPatients / 4).ceil();
    final startItem = totalPatients == 0 ? 0 : ((currentPage - 1) * 4) + 1;
    final endItem = totalPatients == 0
        ? 0
        : (((currentPage - 1) * 4) + patients.length);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'ID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'NOMBRE DEL PACIENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'EDAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TELÉFONO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'ÚLTIMA VISITA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'ACCIONES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          if (patients.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text(
                'No se encontraron pacientes registrados.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            )
          else
            ...patients.map((patient) => _buildRow(patient)),

          // Empty space filler
          if (patients.isNotEmpty && patients.length < 4)
            SizedBox(height: (4 - patients.length) * 60.0),

          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando $startItem - $endItem de $totalPatients pacientes',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (totalPages > 1)
                  Row(
                    children: [
                      _pageButton(
                        '<',
                        currentPage > 1,
                        () => onPageChanged(currentPage - 1),
                      ),
                      ...List.generate(
                        totalPages > 3 ? 3 : totalPages,
                        (i) => _pageButton(
                          '${i + 1}',
                          true,
                          () => onPageChanged(i + 1),
                          isActive: currentPage == i + 1,
                        ),
                      ),
                      if (totalPages > 3) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        _pageButton(
                          '$totalPages',
                          true,
                          () => onPageChanged(totalPages),
                        ),
                      ],
                      _pageButton(
                        '>',
                        currentPage < totalPages,
                        () => onPageChanged(currentPage + 1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Patient patient) {
    final isAlert = patient.hasAlert;
    return InkWell(
      onTap: () => onPatientTap(patient),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isAlert ? AppColors.dangerLight.withValues(alpha: 0.4) : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.borderLight),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  if (isAlert)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.warning,
                        size: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      patient.patientCode,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isAlert
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  AvatarCircle(initials: patient.initials, size: 32),
                  const SizedBox(width: 10),
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '${patient.age ?? "-"}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                patient.phone ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                _formatLastVisit(patient.lastVisit),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => onPatientTap(patient),
                    tooltip: 'Ver expediente',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageButton(
    String text,
    bool enabled,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.white
                  : enabled
                  ? AppColors.textPrimary
                  : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastVisit(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy';
    }
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
