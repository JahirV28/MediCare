import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/tables/upcoming_patients_table.dart';
import '../../widgets/charts/activity_chart.dart';
import '../../widgets/common/patient_autocomplete_field.dart';

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
    Patient? selectedPatient;
    final serviceCtrl = TextEditingController(text: 'Consulta General');
    String selectedTime = '11:00 AM';
    DateTime selectedDate = DateTime.now();
    String? formError;

    final quickServices = [
      'Consulta General',
      'Control Odontológico',
      'Pediatría - Vacunación',
      'Seguimiento Clínico',
      'Urgencia',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_available, color: AppColors.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text('Agendar Cita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final isToday = selectedDate.year == DateTime.now().year &&
                  selectedDate.month == DateTime.now().month &&
                  selectedDate.day == DateTime.now().day;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector interactivo de fecha
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          helpText: 'Seleccionar Fecha de la Cita',
                          cancelText: 'Cancelar',
                          confirmText: 'Seleccionar',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fecha: ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}${isToday ? ' (Hoy)' : ''}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_calendar, size: 13, color: AppColors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Editar Fecha',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Autocomplete de pacientes registrados
                    PatientAutocompleteField(
                      onPatientSelected: (patient) {
                        setDialogState(() {
                          selectedPatient = patient;
                          formError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Campo editable de Motivo / Servicio
                    TextFormField(
                      controller: serviceCtrl,
                      onChanged: (_) {
                        if (formError != null) setDialogState(() => formError = null);
                      },
                      decoration: InputDecoration(
                        labelText: 'Motivo / Servicio *',
                        hintText: 'Escriba o elija el motivo...',
                        prefixIcon: const Icon(Icons.medical_services_outlined, size: 20, color: AppColors.primaryBlue),
                        suffixIcon: serviceCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                                onPressed: () => setDialogState(() => serviceCtrl.clear()),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Sugerencias rápidas de servicio (hacer clic para rellenar/editar)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickServices.map((svc) {
                        final isSelected = serviceCtrl.text == svc;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              serviceCtrl.text = svc;
                              formError = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue : AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlue : AppColors.primaryBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              svc,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.white : AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Selector de hora
                    DropdownButtonFormField<String>(
                      initialValue: selectedTime,
                      decoration: InputDecoration(
                        labelText: 'Hora de la Cita',
                        prefixIcon: const Icon(Icons.access_time, size: 20, color: AppColors.primaryBlue),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      items: ['08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM', '05:00 PM']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedTime = v ?? selectedTime),
                    ),

                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formError!,
                                style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedPatient == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe seleccionar un paciente registrado en la base de datos.'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (serviceCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor indique el motivo o servicio de la cita.'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final pName = selectedPatient!.fullName;
              final pId = selectedPatient!.id ?? 1;
              final sName = serviceCtrl.text.trim();

              final apt = Appointment(
                patientId: pId,
                doctorId: 1,
                serviceId: 1,
                appointmentDate: selectedDate,
                appointmentTime: selectedTime,
                status: 'En Espera',
                patientName: pName,
                serviceName: sName,
              );
              await dashboard.addAppointment(apt);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                final dateFmt = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cita agendada para $pName el $dateFmt a las $selectedTime.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Panel Principal',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final name = auth.currentUser?.fullName ?? 'Dr. Smith';
                          return Text(
                            'Bienvenido de vuelta, $name. Aquí está el resumen de hoy.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
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
                        await dashboard.recordIncome(
                          amount,
                          patientId: apt.patientId,
                          appointmentId: apt.id,
                          concept: 'Cobro de Servicio: ${apt.serviceName ?? "Consulta General"}',
                        );
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
                      todayIndex: dashboard.todayIndex,
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
