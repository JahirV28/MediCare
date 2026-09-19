import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment.dart';
import '../common/avatar_circle.dart';
import '../common/status_badge.dart';

class UpcomingPatientsTable extends StatelessWidget {
  final List<Appointment> appointments;
  final VoidCallback? onViewAll;
  final Function(Appointment)? onStartConsultation;
  final Function(Appointment)? onViewPatientDetail;
  final Function(Appointment, String)? onStatusChanged;
  final Function(Appointment, double)? onCollectPayment;

  const UpcomingPatientsTable({
    super.key,
    required this.appointments,
    this.onViewAll,
    this.onStartConsultation,
    this.onViewPatientDetail,
    this.onStatusChanged,
    this.onCollectPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Próximos Pacientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text(
                    'Ver Todos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 75,
                  child: Text('Hora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Nombre del Paciente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Motivo / Servicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                SizedBox(
                  width: 95,
                  child: Text('Estado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text('Acción', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          if (appointments.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Text(
                'No hay citas programadas para hoy.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            )
          else
            ...appointments.map((apt) => _buildRow(context, apt)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, Appointment apt) {
    final initials = _getInitials(apt.patientName ?? '');
    return InkWell(
      onTap: () => onViewPatientDetail?.call(apt),
      hoverColor: AppColors.background.withValues(alpha: 0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 75,
              child: Text(
                apt.appointmentTime,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  AvatarCircle(initials: initials, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      apt.patientName ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                apt.serviceName ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 95,
              child: _buildStatusBadge(apt.status),
            ),
            SizedBox(
              width: 50,
              child: Center(
                child: PopupMenuButton<String>(
                  tooltip: 'Acciones de Cita',
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.more_horiz, size: 18, color: AppColors.textPrimary),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (action) {
                    switch (action) {
                      case 'consultation':
                        onStartConsultation?.call(apt);
                        break;
                      case 'detail':
                        onViewPatientDetail?.call(apt);
                        break;
                      case 'status':
                        _showChangeStatusDialog(context, apt);
                        break;
                      case 'pay':
                        onCollectPayment?.call(apt, 100.0);
                        break;
                      case 'cancel':
                        onStatusChanged?.call(apt, 'Cancelado');
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'consultation',
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primaryBlue),
                          SizedBox(width: 10),
                          Text('Iniciar Consulta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'detail',
                      child: Row(
                        children: [
                          Icon(Icons.folder_shared_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 10),
                          Text('Ver Expediente', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 18, color: AppColors.warning),
                          SizedBox(width: 10),
                          Text('Cambiar Estado', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pay',
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 18, color: AppColors.success),
                          SizedBox(width: 10),
                          Text('Cobrar Consulta (\$100)', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text('Cancelar Cita', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
      case 'en espera':
      case 'pendiente':
        return StatusBadge.waiting();
      case 'confirmed':
      case 'confirmado':
      case 'confirmada':
        return StatusBadge.confirmed();
      case 'in consultation':
      case 'en consulta':
        return const StatusBadge(
          text: 'En Consulta',
          backgroundColor: Color(0xFFE0E7FF),
          textColor: Color(0xFF4338CA),
        );
      case 'completed':
      case 'atendido':
      case 'finalizado':
        return const StatusBadge(
          text: 'Atendido',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF15803D),
        );
      case 'cancelled':
      case 'cancelado':
      case 'cancelada':
        return const StatusBadge(
          text: 'Cancelado',
          backgroundColor: AppColors.dangerLight,
          textColor: AppColors.danger,
        );
      default:
        return StatusBadge(text: status);
    }
  }

  void _showChangeStatusDialog(BuildContext context, Appointment apt) {
    final statuses = [
      {'label': 'En Espera', 'icon': Icons.hourglass_top, 'color': AppColors.warning},
      {'label': 'En Consulta', 'icon': Icons.medical_services_outlined, 'color': AppColors.primaryBlue},
      {'label': 'Confirmado', 'icon': Icons.check_circle_outline, 'color': AppColors.success},
      {'label': 'Atendido', 'icon': Icons.task_alt, 'color': Color(0xFF15803D)},
      {'label': 'Cancelado', 'icon': Icons.cancel_outlined, 'color': AppColors.danger},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: AppColors.primaryBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Estado de Cita: ${apt.patientName}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((item) {
            final isSelected = apt.status.toLowerCase() == (item['label'] as String).toLowerCase();
            return ListTile(
              leading: Icon(item['icon'] as IconData, color: item['color'] as Color),
              title: Text(
                item['label'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? (item['color'] as Color) : AppColors.textPrimary,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                Navigator.pop(ctx);
                onStatusChanged?.call(apt, item['label'] as String);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }
}
