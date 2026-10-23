import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/patient.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/common/patient_autocomplete_field.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int? patientId, String? patientName)? onNavigateToPatientDetail;

  const CalendarScreen({
    super.key,
    this.onBack,
    this.onNavigateToPatientDetail,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final SupabaseService _api = SupabaseService();
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  // Appointments data
  final Map<String, List<_AppointmentData>> _appointments = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthAppointments();
    });
  }

  Future<void> _loadMonthAppointments() async {
    try {
      final supaAppointments = await _api.getCalendarAppointmentsForMonth(
        _currentMonth.year,
        _currentMonth.month,
      );
      if (mounted) {
        setState(() {
          _appointments.clear();
          supaAppointments.forEach((key, list) {
            _appointments[key] = list.map((item) => _AppointmentData(
              patientId: item['patient_id'] as int?,
              time: item['time'] ?? '09:00',
              patient: item['patient'] ?? 'Paciente',
              service: item['service'] ?? 'Consulta General',
              status: item['status'] ?? 'Confirmado',
            )).toList();
          });
        });
      }
    } catch (e) {
      debugPrint('Error cargando citas del mes: $e');
    }
  }


  List<_AppointmentData> _getAppointmentsForDate(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _appointments[key] ?? [];
  }

  int _getAppointmentCountForDate(DateTime date) {
    return _getAppointmentsForDate(date).length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Breadcrumb(
            items: [
              BreadcrumbItem(label: 'Panel', onTap: widget.onBack),
              const BreadcrumbItem(label: 'Calendario'),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendario de Citas',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestione las citas y horarios de sus pacientes.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showNewAppointmentDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Nueva Cita'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Calendar + Day Detail side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Grid
              Expanded(
                flex: 3,
                child: _buildCalendarCard(),
              ),
              const SizedBox(width: 20),
              // Day Detail
              Expanded(
                flex: 2,
                child: _buildDayDetailCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final totalSlots = ((firstWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  });
                  _loadMonthAppointments();
                },
                icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                splashRadius: 18,
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  });
                  _loadMonthAppointments();
                },
                icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day headers
          Row(
            children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          ...List.generate((totalSlots / 7).ceil(), (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final cellIndex = weekIndex * 7 + dayIndex;
                  final dayNum = cellIndex - (firstWeekday - 1) + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 52));
                  }

                  final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                  final isToday = _isSameDay(date, DateTime.now());
                  final isSelected = _isSameDay(date, _selectedDate);
                  final appointmentCount = _getAppointmentCountForDate(date);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 52,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : isToday
                                  ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.primaryBlue, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.white
                                    : isToday
                                        ? AppColors.primaryBlue
                                        : AppColors.textPrimary,
                              ),
                            ),
                            if (appointmentCount > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  appointmentCount > 3 ? 3 : appointmentCount,
                                  (i) => Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.white.withValues(alpha: 0.8)
                                          : AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayDetailCard() {
    final appointments = _getAppointmentsForDate(_selectedDate);
    final dayName = _getDayName(_selectedDate.weekday);
    final monthName = _getMonthName(_selectedDate.month);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dayName ${_selectedDate.day}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$monthName ${_selectedDate.year}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${appointments.length} citas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          if (appointments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay citas programadas',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Este día está disponible.',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            )
          else
            ...appointments.map((apt) => _buildAppointmentTile(apt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(_AppointmentData apt) {
    Color statusColor;
    Color statusBg;
    String statusText = apt.status;
    switch (apt.status) {
      case 'Confirmada':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        break;
      case 'Pendiente':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        break;
      case 'Cancelada':
        statusColor = AppColors.danger;
        statusBg = AppColors.dangerLight;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusBg = AppColors.borderLight;
    }

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Haga clic para ver el expediente clínico de ${apt.patient}',
        child: InkWell(
          onTap: () {
            widget.onNavigateToPatientDetail?.call(apt.patientId, apt.patient);
          },
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.primaryBlue.withValues(alpha: 0.05),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                // Time
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      apt.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Patient + Service
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              apt.patient,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        apt.service,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNewAppointmentDialog() {
    Patient? selectedPatient;
    final serviceCtrl = TextEditingController(text: 'Consulta General');
    String selectedTime = '09:00';
    DateTime dialogDate = _selectedDate;
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
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.event_note, color: AppColors.primaryBlue, size: 22),
              SizedBox(width: 8),
              Text(
                'Nueva Cita',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contenedor interactivo para editar la fecha
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dialogDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            helpText: 'Seleccionar Fecha de la Cita',
                            cancelText: 'Cancelar',
                            confirmText: 'Seleccionar',
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dialogDate = picked;
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
                              const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fecha: ${_getDayName(dialogDate.weekday)} ${dialogDate.day} de ${_getMonthName(dialogDate.month)}, ${dialogDate.year}',
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

                      // Autocomplete de pacientes registrados en la base de datos
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
                          labelText: 'Hora',
                          prefixIcon: const Icon(Icons.access_time, size: 20, color: AppColors.primaryBlue),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                        items: [
                          '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
                          '11:00', '11:30', '12:00', '13:00', '14:00', '14:30',
                          '15:00', '15:30', '16:00', '16:30', '17:00',
                        ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setDialogState(() => selectedTime = val ?? '09:00'),
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

                final dashboard = context.read<DashboardProvider>();
                final messenger = ScaffoldMessenger.of(context);

                final apt = Appointment(
                  patientId: pId,
                  doctorId: _api.currentUserId ?? 9,
                  serviceId: 1,
                  appointmentDate: dialogDate,
                  appointmentTime: selectedTime,
                  status: 'En Espera',
                  patientName: pName,
                  serviceName: sName,
                );

                final success = await _api.addAppointment(apt);
                if (!success) {
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo agendar la cita. Verifique que no exista colisión de horario.'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }

                setState(() {
                  _selectedDate = dialogDate;
                });

                final now = DateTime.now();
                if (_isSameDay(dialogDate, now)) {
                  await dashboard.loadDashboard();
                }
                await _loadMonthAppointments();

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  final dateStr = '${dialogDate.day}/${dialogDate.month}/${dialogDate.year}';
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Cita agendada para $pName el $dateStr a las $selectedTime.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Agendar Cita'),
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[month];
  }

  String _getDayName(int weekday) {
    const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[weekday];
  }
}

class _AppointmentData {
  final int? patientId;
  final String time;
  final String patient;
  final String service;
  final String status;

  const _AppointmentData({
    this.patientId,
    required this.time,
    required this.patient,
    required this.service,
    required this.status,
  });
}
