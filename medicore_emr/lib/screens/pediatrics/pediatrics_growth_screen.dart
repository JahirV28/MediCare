import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/growth_record.dart';
import '../../models/patient.dart';
import '../../providers/clinical_providers.dart';
import '../../providers/patient_provider.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/common/patient_autocomplete_field.dart';

/// Helper para cálculo preciso y formateo de edad pediátrica
String formatPediatricAge(DateTime? birthDate, {DateTime? atDate}) {
  if (birthDate == null) return 'Edad no registrada';
  final refDate = atDate ?? DateTime.now();
  int years = refDate.year - birthDate.year;
  int months = refDate.month - birthDate.month;
  int days = refDate.day - birthDate.day;
  if (days < 0) {
    months--;
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  if (years <= 0) {
    if (months <= 0) {
      final diffDays = refDate.difference(birthDate).inDays.clamp(0, 999);
      return '$diffDays días';
    }
    return '$months ${months == 1 ? "Mes" : "Meses"}';
  }
  if (months == 0) {
    return '$years ${years == 1 ? "Año" : "Años"}';
  }
  return '$years ${years == 1 ? "Año" : "Años"} $months ${months == 1 ? "Mes" : "Meses"}';
}

/// Estándares clínicos de Crecimiento Infantil de la Organización Mundial de la Salud (OMS 0-5 años)
class WhoStandards {
  // Puntos de referencia OMS a 0, 3, 6, 9, 12, 18, 24, 30, 36, 42, 48, 54, 60 meses
  static const List<double> months = [0, 3, 6, 9, 12, 18, 24, 30, 36, 42, 48, 54, 60];

  // Peso (kg) para varones OMS
  static const List<double> weightP3 =  [2.5, 5.0, 6.4, 7.1, 7.7,  8.8,  9.7, 10.5, 11.3, 12.0, 12.7, 13.4, 14.1];
  static const List<double> weightP50 = [3.3, 6.4, 7.9, 8.9, 9.6, 10.9, 12.2, 13.3, 14.3, 15.3, 16.3, 17.3, 18.3];
  static const List<double> weightP97 = [4.4, 8.0, 9.8, 11.0, 12.0, 13.7, 15.3, 16.8, 18.3, 19.8, 21.2, 22.7, 24.2];

  // Talla / Estatura (cm) para varones OMS
  static const List<double> heightP3 =  [46.1, 57.3, 63.6, 67.5, 71.0, 76.9, 81.7, 86.0, 89.9,  93.1,  96.1,  98.4, 100.7];
  static const List<double> heightP50 = [49.9, 61.4, 67.6, 72.0, 75.7, 82.3, 87.1, 91.9, 96.1,  99.7, 103.3, 106.7, 110.0];
  static const List<double> heightP97 = [53.7, 65.5, 71.6, 76.5, 80.5, 87.7, 92.9, 98.0, 102.7, 106.7, 110.7, 114.6, 119.2];

  // Perímetro Cefálico (cm) para varones OMS
  static const List<double> headP3 =  [31.9, 38.1, 41.0, 42.5, 43.5, 44.8, 45.8, 46.5, 47.0, 47.5, 47.9, 48.2, 48.5];
  static const List<double> headP50 = [34.5, 40.5, 43.3, 45.0, 46.1, 47.4, 48.3, 48.9, 49.5, 50.0, 50.4, 50.7, 51.0];
  static const List<double> headP97 = [37.0, 42.9, 45.8, 47.5, 48.6, 49.9, 50.7, 51.4, 52.0, 52.4, 52.8, 53.2, 53.5];

  static double interpolate(List<double> values, double m) {
    if (m <= months.first) return values.first;
    if (m >= months.last) return values.last;
    for (int i = 0; i < months.length - 1; i++) {
      if (m >= months[i] && m <= months[i + 1]) {
        final span = months[i + 1] - months[i];
        final frac = (m - months[i]) / span;
        // Interpolación suavizada (Hermite Smoothstep) para eliminar quiebres bruscos
        final smoothFrac = frac * frac * (3 - 2 * frac);
        return values[i] + (values[i + 1] - values[i]) * smoothFrac;
      }
    }
    return values.last;
  }

  static int calculatePercentile(double value, double m, String metric) {
    List<double> p3List, p50List, p97List;
    if (metric.contains('Peso')) {
      p3List = weightP3;
      p50List = weightP50;
      p97List = weightP97;
    } else if (metric.contains('Estatura')) {
      p3List = heightP3;
      p50List = heightP50;
      p97List = heightP97;
    } else {
      p3List = headP3;
      p50List = headP50;
      p97List = headP97;
    }
    final p3 = interpolate(p3List, m);
    final p50 = interpolate(p50List, m);
    final p97 = interpolate(p97List, m);

    if (value <= p3) {
      final frac = (value / (p3 > 0 ? p3 : 1)).clamp(0.0, 1.0);
      return (frac * 3).round().clamp(1, 3);
    }
    if (value >= p97) {
      final extra = ((value - p97) / (p97 * 0.1) * 2).round().clamp(0, 2);
      return (97 + extra).clamp(97, 99);
    }
    if (value < p50) {
      final frac = (value - p3) / (p50 - p3);
      return 3 + (frac * 47).round();
    } else {
      final frac = (value - p50) / (p97 - p50);
      return 50 + (frac * 47).round();
    }
  }
}

class PediatricsGrowthScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final int? patientId;

  const PediatricsGrowthScreen({super.key, this.onBack, this.patientId});

  @override
  State<PediatricsGrowthScreen> createState() => _PediatricsGrowthScreenState();
}

class _PediatricsGrowthScreenState extends State<PediatricsGrowthScreen> {
  int _selectedPointIndex = 0;

  static const List<String> _spanishMonths = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patientProv = context.read<PatientProvider>();
      final pediaProv = context.read<PediatricsProvider>();

      if (widget.patientId != null && widget.patientId! > 0) {
        await patientProv.selectPatientById(widget.patientId!);
        await pediaProv.loadGrowthData(widget.patientId!);
        return;
      }

      if (patientProv.patients.isEmpty) {
        await patientProv.loadPatients();
      }

      // Comprobar si el paciente seleccionado actualmente es realmente pediátrico (<= 12 años)
      final current = patientProv.selectedPatient;
      final isChild = current != null && (
        current.id == 8 ||
        (current.age != null && current.age! <= 12) ||
        (current.birthDate != null && DateTime.now().difference(current.birthDate!).inDays < 4380)
      );

      if (isChild && current.id != null) {
        await pediaProv.loadGrowthData(current.id!);
        return;
      }

      // Si el paciente actual es adulto o no hay paciente seleccionado, cargar a Mateo García (ID 8)
      if (patientProv.patients.isNotEmpty) {
        final pediatricPatient = patientProv.patients.firstWhere(
          (p) => p.id == 8 || (p.age != null && p.age! <= 12) || p.fullName.toLowerCase().contains('mateo'),
          orElse: () => patientProv.patients.first,
        );
        patientProv.selectPatient(pediatricPatient);
        if (pediatricPatient.id != null) {
          await pediaProv.loadGrowthData(pediatricPatient.id!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePatient = context.watch<PatientProvider>().selectedPatient;
    final isAdult = activePatient != null && activePatient.age != null && activePatient.age! > 12;

    return Consumer<PediatricsProvider>(
      builder: (context, provider, _) {
        final records = provider.records;
        final selectedMetric = provider.selectedMetric;

        // Asegurar que el índice seleccionado no quede fuera de rango
        if (records.isNotEmpty && _selectedPointIndex >= records.length) {
          _selectedPointIndex = 0;
        }

        final patientName = activePatient?.fullName ?? 'Paciente Pediátrico';
        final patientCode = activePatient?.patientCode.isNotEmpty == true ? '#${activePatient!.patientCode}' : '#P-8472';
        final gender = activePatient?.gender ?? 'Masculino';
        final ageText = formatPediatricAge(activePatient?.birthDate);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb de navegación dinámico
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(
                    label: activePatient != null ? '$patientName ($patientCode)' : 'Sin Paciente Seleccionado',
                    onTap: widget.onBack,
                  ),
                  const BreadcrumbItem(label: 'Curvas de Crecimiento (OMS)'),
                ],
              ),
              const SizedBox(height: 20),

              // Banner del Paciente Pediátrico o Selector de Búsqueda
              if (activePatient == null)
                _buildPatientSelectorBanner(context)
              else
                _buildActivePatientBanner(context, activePatient, provider, records),

              const SizedBox(height: 16),

              // Alerta clínica si el paciente activo es un adulto
              if (isAdult)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aviso Clínico: ${activePatient.fullName} (${activePatient.age} años) es un paciente adulto. Las curvas de la OMS aplican para población pediátrica (0 a 5 años).',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () async {
                          final patientProv = context.read<PatientProvider>();
                          final mateo = patientProv.patients.firstWhere(
                            (p) => p.id == 8 || p.fullName.toLowerCase().contains('mateo'),
                            orElse: () => patientProv.patients.first,
                          );
                          patientProv.selectPatient(mateo);
                          if (mateo.id != null) {
                            await context.read<PediatricsProvider>().loadGrowthData(mateo.id!);
                          }
                        },
                        icon: const Icon(Icons.child_care, size: 16),
                        label: const Text('Ver Mateo García (Pediátrico)'),
                      ),
                    ],
                  ),
                ),

              // Encabezado con selector de métrica y botón de PDF
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gráficas de Crecimiento (Patrón OMS)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$patientName • $gender • $ageText ($patientCode)',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Selector desplegable de métricas OMS
                      Container(
                        width: 270,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMetric,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Peso para la edad (0-5 años)',
                                child: Text('Peso para la edad (0-5 años)', style: TextStyle(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'Estatura para la edad (0-5 años)',
                                child: Text('Estatura para la edad (0-5 años)', style: TextStyle(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'Perímetro Cefálico (0-5 años)',
                                child: Text('Perímetro Cefálico (0-5 años)', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                provider.setMetric(v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await PdfExportService.exportPediatricGrowthPdf(
                              context: context,
                              patientName: patientName,
                              patientCode: patientCode,
                              gender: gender,
                              ageText: ageText,
                              records: records,
                              activeMetric: selectedMetric,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reporte de crecimiento en PDF generado con éxito.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al exportar PDF: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Exportar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dos columnas: Izquierda Gráfica OMS interactiva | Derecha Historial de Medidas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── COLUMNA IZQUIERDA: Lienzo de Gráfica OMS ───
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título y Leyenda
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedMetric,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Row(
                                children: [
                                  _legendPill(const Color(0xFF10B981), '— P50 (Mediana OMS)'),
                                  const SizedBox(width: 14),
                                  _legendPill(const Color(0xFFF59E0B), '— P3 / P97 Límites'),
                                  const SizedBox(width: 14),
                                  _legendPill(AppColors.primaryBlue, '● Mediciones Paciente'),
                                ],
                              ),
                            ],
                          ),

                          // Barra de inspección activa de la medición seleccionada (sin tapar el gráfico)
                          if (records.isNotEmpty && _selectedPointIndex < records.length) ...[
                            const SizedBox(height: 14),
                            _buildActiveInspectionPill(records[_selectedPointIndex], selectedMetric),
                          ],

                          const SizedBox(height: 16),

                          // Custom Painter para curvas y puntos con spline suave
                          SizedBox(
                            height: 380,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: const Size(double.infinity, 380),
                                  painter: _WhoGrowthChartPainter(
                                    records: records,
                                    selectedMetric: selectedMetric,
                                    selectedIndex: _selectedPointIndex,
                                  ),
                                ),
                                if (records.isEmpty)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.info_outline, size: 18, color: AppColors.primaryBlue),
                                          SizedBox(width: 8),
                                          Text(
                                            'Sin mediciones registradas. Agregue un control antropométrico con el botón (+ Medición).',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // ─── COLUMNA DERECHA: Tabla Histórica de Mediciones ───
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // Cabecera con botón (+) para registrar nueva medición
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Historial Somatométrico',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      '${records.length} controles registrados',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Tooltip(
                                  message: 'Registrar nueva medición antropométrica',
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Medición'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () => _showAddMeasurementDialog(context, provider, activePatient),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Encabezados de columnas
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: AppColors.background,
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Fecha / Edad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Peso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Estatura', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 1, child: Text('PC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                SizedBox(width: 32),
                              ],
                            ),
                          ),

                          if (records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.child_care, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No hay mediciones registradas',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Registre el primer control antropométrico del paciente para ver los percentiles OMS.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => _showAddMeasurementDialog(context, provider, activePatient),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Registrar Primera Medición'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: records.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                              itemBuilder: (context, idx) {
                                final r = records[idx];
                                final isSelected = _selectedPointIndex == idx;
                                return InkWell(
                                  onTap: () => setState(() => _selectedPointIndex = idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : null,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                r.ageLabel.isNotEmpty ? r.ageLabel : '${r.ageMonths.toInt()}m',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${r.weightKg} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                              _buildPercentileBadge(r.weightPercentile),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${r.heightCm.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                              _buildPercentileBadge(r.heightPercentile),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text('${r.headCircumferenceCm.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                          tooltip: 'Eliminar medición',
                                          onPressed: () => _confirmDeleteMeasurement(context, r, provider),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          if (records.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextButton.icon(
                                onPressed: () => _showFullHistoryDialog(context, records, provider, activePatient),
                                icon: const Icon(Icons.table_chart_outlined, size: 16),
                                label: const Text('Ver Historial Completo y Detalles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildPercentileBadge(int percentile) {
    Color bg;
    Color fg;
    if (percentile >= 25 && percentile <= 75) {
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
    } else if ((percentile >= 10 && percentile < 25) || (percentile > 75 && percentile <= 90)) {
      bg = AppColors.warning.withValues(alpha: 0.15);
      fg = const Color(0xFFD97706);
    } else {
      bg = AppColors.danger.withValues(alpha: 0.12);
      fg = AppColors.danger;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'P$percentile',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANNER DEL PACIENTE Y SELECTOR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPatientSelectorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.child_care, color: AppColors.primaryBlue, size: 24),
              SizedBox(width: 10),
              Text(
                'Seleccione un Paciente para el Control Pediátrico',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Busque y elija un paciente pediátrico registrado en la base de datos para cargar sus curvas de crecimiento OMS y somatometría.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          PatientAutocompleteField(
            hint: 'Escriba nombre o código (ej: Mateo, P-8472)',
            onPatientSelected: (patient) {
              if (patient != null) {
                context.read<PatientProvider>().selectPatient(patient);
                if (patient.id != null) {
                  context.read<PediatricsProvider>().loadGrowthData(patient.id!);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivePatientBanner(
    BuildContext context,
    Patient activePatient,
    PediatricsProvider provider,
    List<GrowthRecord> records,
  ) {
    final pName = activePatient.fullName;
    final pCode = activePatient.patientCode.isNotEmpty ? '#${activePatient.patientCode}' : '#PT-${activePatient.id}';
    final bDate = activePatient.birthDate;
    final pAgeStr = formatPediatricAge(bDate);
    final pGender = activePatient.gender ?? 'Masculino';
    final pBlood = activePatient.bloodType ?? 'No reg.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Pediatría (OMS)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _infoPill(Icons.cake_outlined, 'Edad: $pAgeStr'),
                    if (bDate != null)
                      _infoPill(
                        Icons.calendar_today_outlined,
                        'Nacimiento: ${bDate.day.toString().padLeft(2, '0')}/${bDate.month.toString().padLeft(2, '0')}/${bDate.year}',
                      ),
                    _infoPill(Icons.person_outline, 'Sexo: $pGender'),
                    _infoPill(Icons.bloodtype_outlined, 'Grupo: $pBlood'),
                    _infoPill(Icons.monitor_weight_outlined, '${records.length} controles registrados'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => _showChangePatientDialog(context),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Cambiar Paciente'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.child_care, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Seleccionar Paciente Pediátrico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Busque por nombre o código de expediente para visualizar o registrar controles antropométricos:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              PatientAutocompleteField(
                hint: 'Escriba nombre o código (ej: Mateo, P-8472)',
                onPatientSelected: (patient) {
                  if (patient != null) {
                    Navigator.of(ctx).pop();
                    context.read<PatientProvider>().selectPatient(patient);
                    if (patient.id != null) {
                      context.read<PediatricsProvider>().loadGrowthData(patient.id!);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _legendPill(Color color, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }

  Widget _buildActiveInspectionPill(GrowthRecord record, String metric) {
    final monthName = _spanishMonths[record.date.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Control: ${record.date.day} $monthName ${record.date.year} (${record.ageLabel.isNotEmpty ? record.ageLabel : "${record.ageMonths.toInt()}m"})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          Row(
            children: [
              Text('Peso: ${record.weightKg} kg (P${record.weightPercentile})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
              const SizedBox(width: 14),
              Text('Talla: ${record.heightCm.toStringAsFixed(1)} cm (P${record.heightPercentile})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
              const SizedBox(width: 14),
              Text('PC: ${record.headCircumferenceCm.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS Y ACCIONES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDeleteMeasurement(BuildContext context, GrowthRecord record, PediatricsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Eliminar Medición', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          '¿Está seguro de eliminar el registro somatométrico del ${record.date.day.toString().padLeft(2, '0')}/${record.date.month.toString().padLeft(2, '0')}/${record.date.year} (${record.ageLabel})? Esta acción se sincronizará con la base de datos.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null) {
      final success = await provider.deleteRecord(record.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Medición eliminada correctamente.' : 'Error al eliminar la medición.'),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
      }
    }
  }

  /// Diálogo para agregar una nueva medición pediátrica de crecimiento
  void _showAddMeasurementDialog(BuildContext context, PediatricsProvider provider, Patient? activePatient) {
    DateTime selectedDate = DateTime.now();
    final bDate = activePatient?.birthDate;

    // Calcular edad inicial en meses y etiqueta
    double initMonths = 24.0;
    String initLabel = '2a';
    if (bDate != null) {
      final diffDays = selectedDate.difference(bDate).inDays;
      initMonths = (diffDays / 30.4375).clamp(0.0, 60.0);
      final y = initMonths ~/ 12;
      final m = (initMonths % 12).round();
      initLabel = y == 0 ? '${m}m' : (m == 0 ? '${y}a' : '${y}a ${m}m');
    }

    final dateController = TextEditingController(text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}');
    final ageLabelController = TextEditingController(text: initLabel);
    final ageMonthsController = TextEditingController(text: initMonths.toStringAsFixed(1));
    final weightController = TextEditingController(text: '14.5');
    final heightController = TextEditingController(text: '93.0');
    final headController = TextEditingController(text: '49.0');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final wVal = double.tryParse(weightController.text) ?? 14.5;
            final hVal = double.tryParse(heightController.text) ?? 93.0;
            final mVal = double.tryParse(ageMonthsController.text) ?? initMonths;
            final liveWPerc = WhoStandards.calculatePercentile(wVal, mVal, 'Peso');
            final liveHPerc = WhoStandards.calculatePercentile(hVal, mVal, 'Estatura');

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.child_care, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Registrar Medición Antropométrica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ingrese los valores de somatometría del paciente para calcular automáticamente los percentiles de referencia de la OMS.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      // Selector de Fecha
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de la Medición',
                          suffixIcon: Icon(Icons.calendar_month, color: AppColors.primaryBlue),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: bDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              dateController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                              if (bDate != null) {
                                final diffDays = picked.difference(bDate).inDays;
                                final newM = (diffDays / 30.4375).clamp(0.0, 60.0);
                                final y = newM ~/ 12;
                                final remM = (newM % 12).round();
                                ageMonthsController.text = newM.toStringAsFixed(1);
                                ageLabelController.text = y == 0 ? '${remM}m' : (remM == 0 ? '${y}a' : '${y}a ${remM}m');
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageLabelController,
                              decoration: const InputDecoration(
                                labelText: 'Etiqueta Edad (ej: 2a 4m)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: ageMonthsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Edad en Meses (ej: 28)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Peso (kg)',
                                border: OutlineInputBorder(),
                                suffixText: 'kg',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Estatura (cm)',
                                border: OutlineInputBorder(),
                                suffixText: 'cm',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: headController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Perímetro Cefálico (cm)',
                          border: OutlineInputBorder(),
                          suffixText: 'cm',
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones / Notas Clínicas (opcional)',
                          hintText: 'Desarrollo psicomotor, alimentación, alertas...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Vista previa en vivo de los percentiles calculados
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                const Text('Percentil Peso: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('P$liveWPerc (OMS)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('Percentil Talla: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('P$liveHPerc (OMS)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  onPressed: () async {
                    final weight = double.tryParse(weightController.text) ?? 14.0;
                    final height = double.tryParse(heightController.text) ?? 92.0;
                    final head = double.tryParse(headController.text) ?? 49.0;
                    final months = (double.tryParse(ageMonthsController.text) ?? initMonths).clamp(0.0, 60.0);

                    final wPerc = WhoStandards.calculatePercentile(weight, months, 'Peso');
                    final hPerc = WhoStandards.calculatePercentile(height, months, 'Estatura');

                    final pid = activePatient?.id ?? provider.currentPatientId ?? widget.patientId ?? 8;
                    final newRecord = GrowthRecord(
                      id: null,
                      patientId: pid,
                      date: selectedDate,
                      ageLabel: ageLabelController.text.isNotEmpty ? ageLabelController.text : '${months.toInt()}m',
                      ageMonths: months,
                      weightKg: weight,
                      weightPercentile: wPerc,
                      heightCm: height,
                      heightPercentile: hPerc,
                      headCircumferenceCm: head,
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    final ok = await provider.addRecord(newRecord, patientId: pid);
                    nav.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Nueva medición antropométrica guardada correctamente.'
                            : 'Aviso: Se guardó localmente.'),
                        backgroundColor: ok ? AppColors.success : AppColors.warning,
                      ),
                    );
                  },
                  child: const Text('Guardar Medición'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Diálogo de historial detallado de todas las mediciones antropométricas
  void _showFullHistoryDialog(
    BuildContext context,
    List<GrowthRecord> records,
    PediatricsProvider provider,
    Patient? activePatient,
  ) {
    final patientName = activePatient?.fullName ?? 'Paciente Pediátrico';
    final patientCode = activePatient?.patientCode.isNotEmpty == true ? '#${activePatient!.patientCode}' : '#P-8472';
    final gender = activePatient?.gender ?? 'Masculino';
    final ageText = formatPediatricAge(activePatient?.birthDate);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historial Antropométrico ($patientName)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  PdfExportService.exportPediatricGrowthPdf(
                    context: context,
                    patientName: patientName,
                    patientCode: patientCode,
                    gender: gender,
                    ageText: ageText,
                    records: records,
                    activeMetric: provider.selectedMetric,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Descargar PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              ),
            ],
          ),
          content: SizedBox(
            width: 780,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Edad')),
                  DataColumn(label: Text('Peso')),
                  DataColumn(label: Text('% Peso')),
                  DataColumn(label: Text('Talla')),
                  DataColumn(label: Text('% Talla')),
                  DataColumn(label: Text('P. Cefálico')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: records.map((r) {
                  return DataRow(cells: [
                    DataCell(Text('${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}')),
                    DataCell(Text(r.ageLabel.isNotEmpty ? r.ageLabel : '${r.ageMonths.toInt()}m')),
                    DataCell(Text('${r.weightKg} kg')),
                    DataCell(_buildPercentileBadge(r.weightPercentile)),
                    DataCell(Text('${r.heightCm.toStringAsFixed(1)} cm')),
                    DataCell(_buildPercentileBadge(r.heightPercentile)),
                    DataCell(Text('${r.headCircumferenceCm.toStringAsFixed(1)} cm')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                        tooltip: 'Eliminar medición',
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _confirmDeleteMeasurement(context, r, provider);
                        },
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Lienzo Dinámico y Suavizado de Gráficas de Crecimiento OMS (Catmull-Rom Spline) ───
class _WhoGrowthChartPainter extends CustomPainter {
  final List<GrowthRecord> records;
  final String selectedMetric;
  final int selectedIndex;

  _WhoGrowthChartPainter({
    required this.records,
    required this.selectedMetric,
    this.selectedIndex = 0,
  });

  /// Trazo de curva spline Catmull-Rom de alta fidelidad matemática
  static Path buildSpline(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  /// Trazo de banda de normalidad sombreada entre P97 y P3
  static Path buildBand(List<Offset> top, List<Offset> bottom) {
    final path = Path();
    if (top.isEmpty || bottom.isEmpty) return path;

    path.moveTo(top[0].dx, top[0].dy);
    for (int i = 0; i < top.length - 1; i++) {
      final p0 = i > 0 ? top[i - 1] : top[i];
      final p1 = top[i];
      final p2 = top[i + 1];
      final p3 = i + 2 < top.length ? top[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.lineTo(bottom.last.dx, bottom.last.dy);

    for (int i = bottom.length - 1; i > 0; i--) {
      final p0 = i < bottom.length - 1 ? bottom[i + 1] : bottom[i];
      final p1 = bottom[i];
      final p2 = bottom[i - 1];
      final p3 = i - 2 >= 0 ? bottom[i - 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 55;
    const double paddingRight = 25;
    const double paddingBottom = 35;
    const double paddingTop = 25;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingBottom - paddingTop;

    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1;

    final axisTextPaint = TextPainter(textDirection: TextDirection.ltr);

    final bool isWeight = selectedMetric.contains('Peso');
    final bool isHeight = selectedMetric.contains('Estatura');

    double yMin, yMax;
    List<String> yLabels;

    if (isWeight) {
      yMin = 0.0;
      yMax = 25.0;
      yLabels = ['0 kg', '5 kg', '10 kg', '15 kg', '20 kg', '25 kg'];
    } else if (isHeight) {
      yMin = 45.0;
      yMax = 125.0;
      yLabels = ['45 cm', '60 cm', '75 cm', '90 cm', '105 cm', '120 cm'];
    } else {
      yMin = 30.0;
      yMax = 55.0;
      yLabels = ['30 cm', '35 cm', '40 cm', '45 cm', '50 cm', '55 cm'];
    }

    // Dibujar líneas y etiquetas del eje Y
    for (int i = 0; i < yLabels.length; i++) {
      final y = (size.height - paddingBottom) - (i * (chartHeight / (yLabels.length - 1)));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      axisTextPaint.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(canvas, Offset(8, y - 6));
    }

    // Dibujar líneas y etiquetas del eje X (0 a 5 años = 0 a 60 meses)
    const xLabels = ['Nacimiento', '1 año', '2 años', '3 años', '4 años', '5 años'];
    for (int i = 0; i < xLabels.length; i++) {
      final x = paddingLeft + (i * (chartWidth / (xLabels.length - 1)));
      canvas.drawLine(Offset(x, paddingTop), Offset(x, size.height - paddingBottom), gridPaint);

      axisTextPaint.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(canvas, Offset(x - (i == 0 ? 0 : (i == xLabels.length - 1 ? 25 : 14)), size.height - paddingBottom + 8));
    }

    double getYPixel(double val) {
      final normalized = ((val - yMin) / (yMax - yMin)).clamp(0.0, 1.0);
      return (size.height - paddingBottom) - (normalized * chartHeight);
    }

    double getXPixel(double ageMonths) {
      final normalized = (ageMonths / 60.0).clamp(0.0, 1.0);
      return paddingLeft + (normalized * chartWidth);
    }

    // Listas de referencia OMS según la métrica seleccionada
    List<double> p3List, p50List, p97List;
    if (isWeight) {
      p3List = WhoStandards.weightP3;
      p50List = WhoStandards.weightP50;
      p97List = WhoStandards.weightP97;
    } else if (isHeight) {
      p3List = WhoStandards.heightP3;
      p50List = WhoStandards.heightP50;
      p97List = WhoStandards.heightP97;
    } else {
      p3List = WhoStandards.headP3;
      p50List = WhoStandards.headP50;
      p97List = WhoStandards.headP97;
    }

    // Puntos de spline interpolados
    final p3Offsets = <Offset>[];
    final p50Offsets = <Offset>[];
    final p97Offsets = <Offset>[];

    for (int i = 0; i < WhoStandards.months.length; i++) {
      final m = WhoStandards.months[i];
      final x = getXPixel(m);
      p3Offsets.add(Offset(x, getYPixel(p3List[i])));
      p50Offsets.add(Offset(x, getYPixel(p50List[i])));
      p97Offsets.add(Offset(x, getYPixel(p97List[i])));
    }

    // 1. Franja sombreada de normalidad OMS (entre P3 y P97)
    final bandPath = buildBand(p97Offsets, p3Offsets);
    final bandPaint = Paint()
      ..color = const Color(0x1510B981) // Verde esmeralda suave traslúcido
      ..style = PaintingStyle.fill;
    canvas.drawPath(bandPath, bandPaint);

    // 2. Curvas de Límites P3 y P97 (Ámbar suave)
    final pBoundsPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(buildSpline(p3Offsets), pBoundsPaint);
    canvas.drawPath(buildSpline(p97Offsets), pBoundsPaint);

    // 3. Curva P50 OMS Mediana (Verde Esmeralda sólido)
    final p50Paint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(buildSpline(p50Offsets), p50Paint);

    // 4. Trayectoria y mediciones del paciente
    if (records.isNotEmpty) {
      final sorted = List<GrowthRecord>.from(records)..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
      final patientOffsets = <Offset>[];

      for (final r in sorted) {
        final val = isWeight ? r.weightKg : (isHeight ? r.heightCm : r.headCircumferenceCm);
        patientOffsets.add(Offset(getXPixel(r.ageMonths), getYPixel(val)));
      }

      // Línea continua conectando mediciones
      if (patientOffsets.length >= 2) {
        final patientLinePaint = Paint()
          ..color = AppColors.primaryBlue
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke;
        canvas.drawPath(buildSpline(patientOffsets), patientLinePaint);
      }

      final activeRecord = (selectedIndex >= 0 && selectedIndex < records.length) ? records[selectedIndex] : null;

      // Marcadores circulares en cada punto
      for (int i = 0; i < sorted.length; i++) {
        final pt = patientOffsets[i];
        final r = sorted[i];
        final isSelected = activeRecord != null && r.id == activeRecord.id;

        if (isSelected) {
          canvas.drawCircle(pt, 12, Paint()..color = AppColors.primaryBlue.withValues(alpha: 0.20));
          canvas.drawCircle(pt, 7, Paint()..color = AppColors.primaryBlue);
          canvas.drawCircle(pt, 3.5, Paint()..color = Colors.white);
        } else {
          canvas.drawCircle(pt, 5.5, Paint()..color = Colors.white);
          canvas.drawCircle(
            pt,
            5.5,
            Paint()
              ..color = AppColors.primaryBlue
              ..strokeWidth = 2.2
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhoGrowthChartPainter oldDelegate) {
    return oldDelegate.selectedMetric != selectedMetric ||
        oldDelegate.records.length != records.length ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
