import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/breadcrumb.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CalendarScreen({super.key, this.onBack});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  // Mock appointments data
  final Map<String, List<_AppointmentData>> _appointments = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
    _generateMockAppointments();
  }

  void _generateMockAppointments() {
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);

    _addAppointment(baseDate, '08:00', 'Ana García', 'Consulta General', 'Confirmada');
    _addAppointment(baseDate, '08:30', 'Carlos López', 'Control', 'Confirmada');
    _addAppointment(baseDate, '09:00', 'María Rodríguez', 'Odontología', 'Pendiente');
    _addAppointment(baseDate, '10:00', 'Juan Perez', 'Seguimiento', 'Confirmada');
    _addAppointment(baseDate, '11:30', 'Laura Sánchez', 'Pediatría', 'Pendiente');
    _addAppointment(baseDate, '14:00', 'Pedro Martínez', 'Consulta General', 'Confirmada');
    _addAppointment(baseDate, '15:00', 'Rosa Fernández', 'Laboratorio', 'Cancelada');
    _addAppointment(baseDate, '16:30', 'Miguel Torres', 'Urgencia', 'Confirmada');

    _addAppointment(baseDate.add(const Duration(days: 1)), '09:00', 'Sofía Herrera', 'Consulta General', 'Pendiente');
    _addAppointment(baseDate.add(const Duration(days: 1)), '10:30', 'Diego Ruiz', 'Control', 'Confirmada');
    _addAppointment(baseDate.add(const Duration(days: 1)), '13:00', 'Valentina Díaz', 'Pediatría', 'Confirmada');

    _addAppointment(baseDate.add(const Duration(days: 2)), '08:30', 'Fernando Morales', 'Odontología', 'Confirmada');
    _addAppointment(baseDate.add(const Duration(days: 2)), '11:00', 'Camila Ortiz', 'Consulta General', 'Pendiente');

    _addAppointment(baseDate.add(const Duration(days: 4)), '09:00', 'Andrés Vega', 'Control', 'Confirmada');
    _addAppointment(baseDate.add(const Duration(days: 4)), '14:00', 'Lucía Mendoza', 'Laboratorio', 'Pendiente');
    _addAppointment(baseDate.add(const Duration(days: 4)), '15:30', 'Ricardo Castro', 'Consulta General', 'Confirmada');

    _addAppointment(baseDate.add(const Duration(days: 7)), '08:00', 'Elena Vargas', 'Seguimiento', 'Confirmada');
    _addAppointment(baseDate.add(const Duration(days: 7)), '10:00', 'Pablo Flores', 'Odontología', 'Pendiente');

    _addAppointment(baseDate.subtract(const Duration(days: 1)), '09:00', 'Isabel Ramírez', 'Consulta General', 'Confirmada');
    _addAppointment(baseDate.subtract(const Duration(days: 1)), '11:00', 'Roberto Silva', 'Control', 'Confirmada');
    _addAppointment(baseDate.subtract(const Duration(days: 3)), '14:00', 'Carmen Gutiérrez', 'Pediatría', 'Confirmada');
  }

  void _addAppointment(DateTime date, String time, String patient, String service, String status) {
    final key = '${date.year}-${date.month}-${date.day}';
    _appointments.putIfAbsent(key, () => []);
    _appointments[key]!.add(_AppointmentData(
      time: time,
      patient: patient,
      service: service,
      status: status,
    ));
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

    return Container(
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
                Text(
                  apt.patient,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  apt.service,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
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
    );
  }

  void _showNewAppointmentDialog() {
    final patientCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    String selectedTime = '09:00';

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
            width: 380,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha: ${_getDayName(_selectedDate.weekday)} ${_selectedDate.day} de ${_getMonthName(_selectedDate.month)}, ${_selectedDate.year}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: patientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Paciente',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: serviceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Servicio / Motivo',
                        prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTime,
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        prefixIcon: Icon(Icons.access_time, size: 20),
                      ),
                      items: [
                        '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
                        '11:00', '11:30', '12:00', '13:00', '14:00', '14:30',
                        '15:00', '15:30', '16:00', '16:30', '17:00',
                      ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() => selectedTime = val ?? '09:00'),
                    ),
                  ],
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
                if (patientCtrl.text.isNotEmpty && serviceCtrl.text.isNotEmpty) {
                  final pName = patientCtrl.text.trim();
                  final sName = serviceCtrl.text.trim();
                  setState(() {
                    _addAppointment(
                      _selectedDate,
                      selectedTime,
                      pName,
                      sName,
                      'Pendiente',
                    );
                  });

                  final now = DateTime.now();
                  if (_isSameDay(_selectedDate, now)) {
                    final apt = Appointment(
                      patientId: 5,
                      doctorId: 1,
                      serviceId: 1,
                      appointmentDate: _selectedDate,
                      appointmentTime: selectedTime,
                      status: 'En Espera',
                      patientName: pName,
                      serviceName: sName,
                    );
                    await context.read<DashboardProvider>().addAppointment(apt);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cita agendada para $pName a las $selectedTime.'),
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
  final String time;
  final String patient;
  final String service;
  final String status;

  const _AppointmentData({
    required this.time,
    required this.patient,
    required this.service,
    required this.status,
  });
}
