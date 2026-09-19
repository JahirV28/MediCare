import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/tables/upcoming_patients_table.dart';
import '../../widgets/charts/activity_chart.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPatients;
  final VoidCallback? onNavigateToNewPatient;
  final VoidCallback? onNavigateToNewConsultation;
  final VoidCallback? onNavigateToCalendar;
  final Function(int patientId)? onNavigateToPatientDetail;
  final Function(int patientId)? onNavigateToConsultation;

  const DashboardScreen({
    super.key,
    this.onNavigateToPatients,
    this.onNavigateToNewPatient,
    this.onNavigateToNewConsultation,
    this.onNavigateToCalendar,
    this.onNavigateToPatientDetail,
    this.onNavigateToConsultation,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  void _showQuickAppointmentDialog(BuildContext context, DashboardProvider dashboard) {
    final patientCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: 'Consulta General');
    String selectedTime = '11:00 AM';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_available, color: AppColors.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text('Agendar Cita para Hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Paciente',
                  hintText: 'Ej. Juan Pérez',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serviceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo / Servicio',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedTime,
                decoration: const InputDecoration(
                  labelText: 'Hora',
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: ['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:30 PM', '04:00 PM', '05:00 PM']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => selectedTime = v ?? selectedTime,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (patientCtrl.text.trim().isNotEmpty) {
                final apt = Appointment(
                  patientId: 5,
                  doctorId: 1,
                  serviceId: 1,
                  appointmentDate: DateTime.now(),
                  appointmentTime: selectedTime,
                  status: 'En Espera',
                  patientName: patientCtrl.text.trim(),
                  serviceName: serviceCtrl.text.trim().isNotEmpty ? serviceCtrl.text.trim() : 'Consulta General',
                );
                await dashboard.addAppointment(apt);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cita agendada para ${patientCtrl.text.trim()} hoy a las $selectedTime.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Agendar Cita'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, _) {
        if (dashboard.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel Principal',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bienvenido de vuelta, Dr. Smith. Aquí está el resumen de hoy.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showQuickAppointmentDialog(context, dashboard),
                        icon: const Icon(Icons.event_note_outlined, size: 18),
                        label: const Text('Nueva Cita'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: widget.onNavigateToNewPatient,
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Registrar Paciente'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: widget.onNavigateToNewConsultation,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Nueva Consulta'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.calendar_today,
                      value: '${dashboard.appointmentsToday}',
                      label: 'Citas',
                      badgeText: 'Hoy',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      icon: Icons.people_outline,
                      value: '${dashboard.activePatients}',
                      label: 'Pacientes Activos',
                      badgeText: 'Total',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      value: '\$${dashboard.dailyIncome.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      label: 'Ingresos del Día',
                      badgeText: 'Hoy',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Table + Chart
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upcoming Patients
                  Expanded(
                    flex: 3,
                    child: UpcomingPatientsTable(
                      appointments: dashboard.upcomingAppointments,
                      onViewAll: widget.onNavigateToCalendar,
                      onViewPatientDetail: (apt) => widget.onNavigateToPatientDetail?.call(apt.patientId),
                      onStartConsultation: (apt) => widget.onNavigateToConsultation?.call(apt.patientId),
                      onStatusChanged: (apt, newStatus) async {
                        if (apt.id != null) {
                          await dashboard.updateAppointmentStatus(apt.id!, newStatus);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Estado de "${apt.patientName}" actualizado a "$newStatus".'),
                                backgroundColor: AppColors.primaryBlue,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      onCollectPayment: (apt, amount) async {
                        await dashboard.recordIncome(amount);
                        if (apt.id != null) {
                          await dashboard.updateAppointmentStatus(apt.id!, 'Atendido');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cobro de \$${amount.toStringAsFixed(0)} registrado con éxito para "${apt.patientName}".'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Activity Chart
                  Expanded(
                    flex: 2,
                    child: ActivityChart(
                      data: dashboard.weeklyActivity,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
