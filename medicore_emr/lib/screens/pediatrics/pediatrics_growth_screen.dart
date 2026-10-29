import 'dart:math' as math;
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
  static const List<double> months = [
    0,
    3,
    6,
    9,
    12,
    18,
    24,
    30,
    36,
    42,
    48,
    54,
    60,
  ];

  // Peso (kg) para varones OMS
  static const List<double> weightP3 = [
    2.5,
    5.0,
    6.4,
    7.1,
    7.7,
    8.8,
    9.7,
    10.5,
    11.3,
    12.0,
    12.7,
    13.4,
    14.1,
  ];
  static const List<double> weightP50 = [
    3.3,
    6.4,
    7.9,
    8.9,
    9.6,
    10.9,
    12.2,
    13.3,
    14.3,
    15.3,
    16.3,
    17.3,
    18.3,
  ];
  static const List<double> weightP97 = [
    4.4,
    8.0,
    9.8,
    11.0,
    12.0,
    13.7,
    15.3,
    16.8,
    18.3,
    19.8,
    21.2,
    22.7,
    24.2,
  ];

  // Talla / Estatura (cm) para varones OMS
  static const List<double> heightP3 = [
    46.1,
    57.3,
    63.6,
    67.5,
    71.0,
    76.9,
    81.7,
    86.0,
    89.9,
    93.1,
    96.1,
    98.4,
    100.7,
  ];
  static const List<double> heightP50 = [
    49.9,
    61.4,
    67.6,
    72.0,
    75.7,
    82.3,
    87.1,
    91.9,
    96.1,
    99.7,
    103.3,
    106.7,
    110.0,
  ];
  static const List<double> heightP97 = [
    53.7,
    65.5,
    71.6,
    76.5,
    80.5,
    87.7,
    92.9,
    98.0,
    102.7,
    106.7,
    110.7,
    114.6,
    119.2,
  ];

  // Perímetro Cefálico (cm) para varones OMS
  static const List<double> headP3 = [
    31.9,
    38.1,
    41.0,
    42.5,
    43.5,
    44.8,
    45.8,
    46.5,
    47.0,
    47.5,
    47.9,
    48.2,
    48.5,
  ];
  static const List<double> headP50 = [
    34.5,
    40.5,
    43.3,
    45.0,
    46.1,
    47.4,
    48.3,
    48.9,
    49.5,
    50.0,
    50.4,
    50.7,
    51.0,
  ];
  static const List<double> headP97 = [
    37.0,
    42.9,
    45.8,
    47.5,
    48.6,
    49.9,
    50.7,
    51.4,
    52.0,
    52.4,
    52.8,
    53.2,
    53.5,
  ];

  static double interpolate(List<double> values, double m) {
    if (m <= months.first) return values.first;
    if (m >= months.last) return values.last;
    for (int i = 0; i < months.length - 1; i++) {
      if (m >= months[i] && m <= months[i + 1]) {
        final span = months[i + 1] - months[i];
        final frac = (m - months[i]) / span;
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

  static String getClinicalDiagnosis(int percentile, String metric) {
    if (percentile >= 25 && percentile <= 75) {
      return metric.contains('Peso')
          ? 'Normopeso (Crecimiento Eutrófico)'
          : (metric.contains('Estatura')
              ? 'Talla Adecuada (Normal)'
              : 'Normocefalia (Adecuado)');
    } else if (percentile >= 10 && percentile < 25) {
      return metric.contains('Peso')
          ? 'Percentil Bajo Normal (Vigilancia)'
          : 'Talla Baja Normal';
    } else if (percentile > 75 && percentile <= 90) {
      return metric.contains('Peso')
          ? 'Percentil Alto Normal (Vigilancia)'
          : 'Talla Alta Normal';
    } else if (percentile < 10) {
      return percentile <= 3
          ? (metric.contains('Peso')
              ? 'Alerta: Bajo Peso Severo / Desnutrición'
              : 'Alerta: Talla Baja Severa')
          : (metric.contains('Peso')
              ? 'Riesgo de Desnutrición'
              : 'Riesgo de Talla Baja');
    } else {
      return percentile >= 97
          ? (metric.contains('Peso')
              ? 'Alerta: Sobrepeso / Obesidad Pediátrica'
              : 'Talla Muy Alta')
          : (metric.contains('Peso')
              ? 'Riesgo de Sobrepeso'
              : 'Talla Alta');
    }
  }

  static Color getPercentileColor(int percentile) {
    if (percentile >= 25 && percentile <= 75) {
      return AppColors.success;
    } else if ((percentile >= 10 && percentile < 25) ||
        (percentile > 75 && percentile <= 90)) {
      return const Color(0xFFD97706); // Amber
    } else {
      return AppColors.danger;
    }
  }
}

/// Helper para cálculo y mapeo bidireccional de coordenadas del lienzo
class GrowthChartLayout {
  final double chartWidth;
  final double chartHeight;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final double yMin;
  final double yMax;
  final double maxMonths;

  GrowthChartLayout({
    required this.chartWidth,
    required this.chartHeight,
    this.paddingLeft = 55.0,
    this.paddingRight = 30.0,
    this.paddingTop = 32.0,
    this.paddingBottom = 40.0,
    required this.yMin,
    required this.yMax,
    required this.maxMonths,
  });

  double getXPixel(double ageMonths) {
    if (maxMonths <= 0) return paddingLeft;
    final norm = (ageMonths / maxMonths).clamp(0.0, 1.0);
    return paddingLeft + (norm * chartWidth);
  }

  double getYPixel(double val) {
    if (yMax <= yMin) return paddingTop + chartHeight / 2;
    final norm = ((val - yMin) / (yMax - yMin)).clamp(0.0, 1.0);
    return (paddingTop + chartHeight) - (norm * chartHeight);
  }

  static double resolveMaxMonths(List<GrowthRecord> records, String mode) {
    if (mode == '0-24m') return 24.0;
    if (mode == '0-36m') return 36.0;
    if (mode == '0-5a') return 60.0;

    // Modo 'auto' adaptativo según los datos registrados del paciente:
    if (records.isEmpty) return 60.0;
    double maxAge = 0.0;
    for (final r in records) {
      if (r.ageMonths > maxAge) maxAge = r.ageMonths;
    }
    if (maxAge <= 24.0) return 24.0;
    if (maxAge <= 36.0) return 36.0;
    return 60.0;
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
  String _timeScaleMode = 'auto'; // 'auto', '0-24m', '0-36m', '0-5a'

  static const List<String> _spanishMonths = [
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

      final current = patientProv.selectedPatient;
      final isChild = current != null &&
          (current.id == 8 ||
              (current.age != null && current.age! <= 12) ||
              current.fullName.toLowerCase().contains('mateo'));

      if (isChild && current.id != null) {
        await pediaProv.loadGrowthData(current.id!);
        return;
      }

      // Si el paciente actual es adulto o no hay paciente pediátrico, seleccionar directamente a Mateo García (ID 8)
      // quien cuenta con su historial de 6 mediciones reales en Supabase
      await patientProv.selectPatientById(8);
      await pediaProv.loadGrowthData(8);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePatient = context.watch<PatientProvider>().selectedPatient;
    final isAdult = activePatient != null &&
        activePatient.age != null &&
        activePatient.age! > 12;

    return Consumer<PediatricsProvider>(
      builder: (context, provider, _) {
        final records = provider.records;
        final selectedMetric = provider.selectedMetric;

        // Asegurar que el índice seleccionado no quede fuera de rango
        if (records.isNotEmpty && _selectedPointIndex >= records.length) {
          _selectedPointIndex = 0;
        }

        final patientName = activePatient?.fullName ?? 'Paciente Pediátrico';
        final patientCode = activePatient?.patientCode.isNotEmpty == true
            ? '#${activePatient!.patientCode}'
            : '#P-8472';
        final gender = activePatient?.gender ?? 'Masculino';
        final ageText = formatPediatricAge(activePatient?.birthDate);

        // Resolver rango temporal máximo dinámico
        final maxMonths =
            GrowthChartLayout.resolveMaxMonths(records, _timeScaleMode);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb de navegación
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(
                    label: activePatient != null
                        ? '$patientName ($patientCode)'
                        : 'Sin Paciente Seleccionado',
                    onTap: widget.onBack,
                  ),
                  const BreadcrumbItem(label: 'Curvas de Crecimiento (OMS)'),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Banner del Paciente Pediátrico Activo
              if (activePatient == null)
                _buildPatientSelectorBanner(context)
              else
                _buildActivePatientBanner(
                  context,
                  activePatient,
                  provider,
                  records,
                ),

              const SizedBox(height: 16),

              // 3. Aviso clínico si el paciente activo es adulto
              if (isAdult)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aviso Clínico: ${activePatient.fullName} (${activePatient.age} años) es un paciente adulto. Las curvas de la OMS aplican para población pediátrica (0 a 5 años).',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () async {
                          final patientProv = context.read<PatientProvider>();
                          final pediaProv = context.read<PediatricsProvider>();
                          await patientProv.selectPatientById(8);
                          await pediaProv.loadGrowthData(8);
                        },
                        icon: const Icon(Icons.child_care, size: 16),
                        label: const Text('Ver Mateo García (Pediátrico)'),
                      ),
                    ],
                  ),
                ),

              // 4. Tarjetas KPI de Estado Somatométrico (cuando hay datos)
              if (records.isNotEmpty) ...[
                _buildSomatometricKpiCards(records),
                const SizedBox(height: 20),
              ],

              // 5. Barra de controles: Métrica, Escala Temporal y Exportar PDF
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Selector de Métrica OMS
                      Container(
                        width: 250,
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
                                child: Text(
                                  '⚖️ Peso para la edad',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Estatura para la edad (0-5 años)',
                                child: Text(
                                  '📏 Estatura para la edad',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Perímetro Cefálico (0-5 años)',
                                child: Text(
                                  '🧠 Perímetro Cefálico',
                                  style: TextStyle(fontSize: 13),
                                ),
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

                      // Selector de Escala de Edad (Adaptativo vs Fijo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _timeScaleMode,
                            items: const [
                              DropdownMenuItem(
                                value: 'auto',
                                child: Text(
                                  '⏱️ Auto (Adaptado a edad)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: '0-24m',
                                child: Text(
                                  '0 - 24m (Lactante)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: '0-36m',
                                child: Text(
                                  '0 - 3 Años (Infante)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: '0-5a',
                                child: Text(
                                  '0 - 5 Años (Preescolar)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _timeScaleMode = v);
                              }
                            },
                          ),
                        ),
                      ),

                      // Botón Exportar PDF
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
                                  content: Text(
                                    'Reporte de crecimiento en PDF generado con éxito.',
                                  ),
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
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: const Text('Exportar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. Dos columnas: Izquierda Gráfica OMS adaptativa | Derecha Historial de Medidas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── COLUMNA IZQUIERDA: Lienzo Dinámico OMS ───
                  Expanded(
                    flex: 3,
                    child: records.isEmpty
                        ? _buildEmptyChartState(
                            context,
                            activePatient,
                            provider,
                          )
                        : Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título y Leyenda de Curvas OMS
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedMetric,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        _legendPill(
                                          const Color(0xFF10B981),
                                          '— P50 (Mediana OMS)',
                                        ),
                                        _legendPill(
                                          const Color(0xFFF59E0B),
                                          '— P3 / P97 Límites',
                                        ),
                                        _legendPill(
                                          AppColors.primaryBlue,
                                          '● Mediciones Paciente',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Barra de inspección activa de la medición seleccionada
                                if (records.isNotEmpty &&
                                    _selectedPointIndex < records.length) ...[
                                  const SizedBox(height: 14),
                                  _buildActiveInspectionPill(
                                    records,
                                    _selectedPointIndex,
                                    selectedMetric,
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Lienzo interactivo con detección de toques directos
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final chartW =
                                        constraints.maxWidth - 55 - 30;
                                    const chartH = 380.0 - 32 - 40;

                                    // Calcular límites Y dinámicos para evitar cualquier desbordamiento
                                    final isWeight =
                                        selectedMetric.contains('Peso');
                                    final isHeight =
                                        selectedMetric.contains('Estatura');

                                    double maxPatientVal = 0.0;
                                    for (final r in records) {
                                      final v = isWeight
                                          ? r.weightKg
                                          : (isHeight
                                              ? r.heightCm
                                              : r.headCircumferenceCm);
                                      if (v > maxPatientVal) maxPatientVal = v;
                                    }

                                    double yMin = isWeight
                                        ? 0.0
                                        : (isHeight ? 45.0 : 30.0);
                                    double yMax;

                                    if (isWeight) {
                                      final whoMax = WhoStandards.interpolate(
                                        WhoStandards.weightP97,
                                        maxMonths,
                                      );
                                      final target = math.max(
                                              whoMax, maxPatientVal) *
                                          1.15;
                                      final step = target > 40
                                          ? 10.0
                                          : (target > 20 ? 4.0 : 3.0);
                                      yMax =
                                          (target / step).ceil() * step;
                                    } else if (isHeight) {
                                      final whoMax = WhoStandards.interpolate(
                                        WhoStandards.heightP97,
                                        maxMonths,
                                      );
                                      final target = math.max(
                                              whoMax, maxPatientVal) *
                                          1.08;
                                      final step = target > 130 ? 20.0 : 15.0;
                                      yMax = ((target - yMin) / step).ceil() *
                                              step +
                                          yMin;
                                    } else {
                                      final whoMax = WhoStandards.interpolate(
                                        WhoStandards.headP97,
                                        maxMonths,
                                      );
                                      final target = math.max(
                                              whoMax, maxPatientVal) *
                                          1.08;
                                      yMax = math.max(55.0,
                                          ((target - yMin) / 5.0).ceil() * 5.0 +
                                              yMin);
                                    }

                                    final layout = GrowthChartLayout(
                                      chartWidth: chartW,
                                      chartHeight: chartH,
                                      paddingLeft: 55,
                                      paddingRight: 30,
                                      paddingTop: 32,
                                      paddingBottom: 40,
                                      yMin: yMin,
                                      yMax: yMax,
                                      maxMonths: maxMonths,
                                    );

                                    return GestureDetector(
                                      onTapDown: (details) {
                                        final localPos = details.localPosition;
                                        int? closestIdx;
                                        double minDistance = 35.0;

                                        for (int i = 0;
                                            i < records.length;
                                            i++) {
                                          final r = records[i];
                                          final val = isWeight
                                              ? r.weightKg
                                              : (isHeight
                                                  ? r.heightCm
                                                  : r.headCircumferenceCm);
                                          final pt = Offset(
                                            layout.getXPixel(r.ageMonths),
                                            layout.getYPixel(val),
                                          );
                                          final dist =
                                              (localPos - pt).distance;
                                          if (dist < minDistance) {
                                            minDistance = dist;
                                            closestIdx = i;
                                          }
                                        }

                                        if (closestIdx != null) {
                                          setState(() =>
                                              _selectedPointIndex = closestIdx!);
                                        }
                                      },
                                      child: CustomPaint(
                                        size: Size(constraints.maxWidth, 380),
                                        painter: _AdaptiveWhoChartPainter(
                                          records: records,
                                          selectedMetric: selectedMetric,
                                          selectedIndex: _selectedPointIndex,
                                          layout: layout,
                                        ),
                                      ),
                                    );
                                  },
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Historial Somatométrico',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${records.length} controles registrados',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Tooltip(
                                  message:
                                      'Registrar nueva medición antropométrica',
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Medición'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () => _showAddMeasurementDialog(
                                      context,
                                      provider,
                                      activePatient,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Encabezados de columnas
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: AppColors.background,
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Fecha / Edad',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Peso',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Estatura',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'PC',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 72),
                              ],
                            ),
                          ),

                          if (records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.child_care,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No hay mediciones registradas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Registre el primer control antropométrico del paciente para ver los percentiles OMS.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => _showAddMeasurementDialog(
                                      context,
                                      provider,
                                      activePatient,
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      'Registrar Primera Medición',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: records.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                height: 1,
                                color: AppColors.borderLight,
                              ),
                              itemBuilder: (context, idx) {
                                final r = records[idx];
                                final isSelected = _selectedPointIndex == idx;
                                return InkWell(
                                  onTap: () =>
                                      setState(() => _selectedPointIndex = idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    color: isSelected
                                        ? AppColors.primaryBlue.withValues(
                                            alpha: 0.08,
                                          )
                                        : null,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? AppColors.primaryBlue
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                r.ageLabel.isNotEmpty
                                                    ? r.ageLabel
                                                    : '${r.ageMonths.toInt()}m',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r.weightKg} kg',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              _buildPercentileBadge(
                                                r.weightPercentile,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r.heightCm.toStringAsFixed(1)} cm',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              _buildPercentileBadge(
                                                r.heightPercentile,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${r.headCircumferenceCm.toStringAsFixed(1)} cm',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: AppColors.primaryBlue,
                                          ),
                                          tooltip: 'Modificar medición',
                                          onPressed: () =>
                                              _showEditMeasurementDialog(
                                            context,
                                            r,
                                            provider,
                                            activePatient,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: AppColors.danger,
                                          ),
                                          tooltip: 'Eliminar medición',
                                          onPressed: () =>
                                              _confirmDeleteMeasurement(
                                            context,
                                            r,
                                            provider,
                                          ),
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
                                onPressed: () => _showFullHistoryDialog(
                                  context,
                                  records,
                                  provider,
                                  activePatient,
                                ),
                                icon: const Icon(
                                  Icons.table_chart_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Ver Historial Completo y Detalles',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // TARJETAS KPI SOMATOMÉTRICAS Y ESTADO NUTRICIONAL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSomatometricKpiCards(List<GrowthRecord> records) {
    final sorted = List<GrowthRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    // Calcular velocidad de ganancia de peso si hay al menos 2 mediciones
    String velocityText = 'Control inicial';
    Color velocityColor = AppColors.primaryBlue;
    if (sorted.length >= 2) {
      final prev = sorted[1];
      final monthDiff = latest.ageMonths - prev.ageMonths;
      if (monthDiff > 0) {
        final gainGrams = ((latest.weightKg - prev.weightKg) * 1000).round();
        final rate = (gainGrams / monthDiff).round();
        velocityText = '${rate >= 0 ? "+" : ""}$rate g / mes';
        velocityColor = rate >= 150 ? AppColors.success : const Color(0xFFD97706);
      }
    }

    final diag =
        WhoStandards.getClinicalDiagnosis(latest.weightPercentile, 'Peso');
    final diagColor =
        WhoStandards.getPercentileColor(latest.weightPercentile);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final cardWidth = isCompact
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              width: cardWidth,
              title: 'Último Peso',
              value: '${latest.weightKg} kg',
              badge: 'Percentil ${latest.weightPercentile} (OMS)',
              badgeColor: diagColor,
              icon: Icons.monitor_weight_outlined,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: AppColors.primaryBlue,
            ),
            _buildKpiCard(
              width: cardWidth,
              title: 'Última Talla',
              value: '${latest.heightCm.toStringAsFixed(1)} cm',
              badge: 'Percentil ${latest.heightPercentile} (OMS)',
              badgeColor: WhoStandards.getPercentileColor(latest.heightPercentile),
              icon: Icons.height_outlined,
              iconBg: const Color(0xFFECFDF5),
              iconColor: AppColors.success,
            ),
            _buildKpiCard(
              width: cardWidth,
              title: 'Perímetro Cefálico',
              value: '${latest.headCircumferenceCm.toStringAsFixed(1)} cm',
              badge: 'Desarrollo Craneal',
              badgeColor: AppColors.textSecondary,
              icon: Icons.psychology_outlined,
              iconBg: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
            ),
            _buildKpiCard(
              width: cardWidth,
              title: 'Diagnóstico Nutricional',
              value: diag,
              badge: velocityText,
              badgeColor: velocityColor,
              icon: Icons.favorite_border_rounded,
              iconBg: diagColor.withValues(alpha: 0.12),
              iconColor: diagColor,
              isTitleLong: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    bool isTitleLong = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTitleLong ? 14 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ESTADO VACÍO CLARO Y SIN CONFUSIÓN (SIN GRÁFICA FANTASMA)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyChartState(
    BuildContext context,
    Patient? activePatient,
    PediatricsProvider provider,
  ) {
    final isAdult = activePatient != null &&
        activePatient.age != null &&
        activePatient.age! > 12;
    final name = activePatient?.fullName ?? 'el paciente';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 54,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sin Mediciones Somatométricas Registradas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isAdult
                    ? '$name (${activePatient.age} años) es un paciente adulto registrado en el sistema. Las curvas antropométricas de la OMS están calibradas exclusivamente para infantes (0 a 5 años). Puede registrar un control somatométrico o cambiar al paciente pediátrico.'
                    : 'Aún no se han registrado mediciones antropométricas para $name. Para visualizar las curvas percentilares de la OMS (peso, talla y perímetro cefálico), agregue el primer control clínico.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddMeasurementDialog(
                      context,
                      provider,
                      activePatient,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar Primer Control'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final patientProv = context.read<PatientProvider>();
                      final pediaProv = context.read<PediatricsProvider>();
                      await patientProv.selectPatientById(8);
                      await pediaProv.loadGrowthData(8);
                    },
                    icon: const Icon(
                      Icons.child_care,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                    label: const Text(
                      'Cargar Mateo García (Pediátrico - 6 controles)',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      side: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INSPECCIÓN ACTIVA DE PUNTOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildActiveInspectionPill(
    List<GrowthRecord> records,
    int selectedIdx,
    String metric,
  ) {
    if (selectedIdx < 0 || selectedIdx >= records.length) {
      return const SizedBox.shrink();
    }
    final record = records[selectedIdx];
    final monthName = _spanishMonths[record.date.month - 1];

    final isWeight = metric.contains('Peso');
    final isHeight = metric.contains('Estatura');

    final int perc = isWeight
        ? record.weightPercentile
        : (isHeight ? record.heightPercentile : 50);

    final diag = WhoStandards.getClinicalDiagnosis(perc, metric);
    final diagColor = WhoStandards.getPercentileColor(perc);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control: ${record.date.day} $monthName ${record.date.year} (${record.ageLabel.isNotEmpty ? record.ageLabel : "${record.ageMonths.toInt()}m"})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    diag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: diagColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Peso: ${record.weightKg} kg (P${record.weightPercentile})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isWeight ? FontWeight.w700 : FontWeight.w600,
                  color: isWeight ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
              Text(
                'Talla: ${record.heightCm.toStringAsFixed(1)} cm (P${record.heightPercentile})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isHeight ? FontWeight.w700 : FontWeight.w600,
                  color: isHeight ? AppColors.success : AppColors.textPrimary,
                ),
              ),
              Text(
                'PC: ${record.headCircumferenceCm.toStringAsFixed(1)} cm',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => _showEditMeasurementDialog(
                  context,
                  record,
                  context.read<PediatricsProvider>(),
                  context.read<PatientProvider>().selectedPatient,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Modificar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPercentileBadge(int percentile) {
    Color bg;
    Color fg;
    if (percentile >= 25 && percentile <= 75) {
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
    } else if ((percentile >= 10 && percentile < 25) ||
        (percentile > 75 && percentile <= 90)) {
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
                  context.read<PediatricsProvider>().loadGrowthData(
                    patient.id!,
                  );
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
    final pCode = activePatient.patientCode.isNotEmpty
        ? '#${activePatient.patientCode}'
        : '#PT-${activePatient.id}';
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight.withValues(
                          alpha: 0.15,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                    _infoPill(
                      Icons.monitor_weight_outlined,
                      '${records.length} controles registrados',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            children: [
              if (activePatient.id != 8)
                ElevatedButton.icon(
                  onPressed: () async {
                    final pProv = context.read<PatientProvider>();
                    final pediaProv = context.read<PediatricsProvider>();
                    await pProv.selectPatientById(8);
                    await pediaProv.loadGrowthData(8);
                  },
                  icon: const Icon(Icons.child_care, size: 16),
                  label: const Text('Mateo García (2a 4m)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _showChangePatientDialog(context),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Cambiar Paciente'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
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
            Text(
              'Seleccionar Paciente Pediátrico',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
                      context.read<PediatricsProvider>().loadGrowthData(
                        patient.id!,
                      );
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
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _legendPill(Color color, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS DE REGISTRO Y GESTIÓN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDeleteMeasurement(
    BuildContext context,
    GrowthRecord record,
    PediatricsProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'Eliminar Medición',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null) {
      final success = await provider.deleteRecord(record.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Medición eliminada correctamente.'
                  : 'Error al eliminar la medición.',
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
      }
    }
  }

  void _showAddMeasurementDialog(
    BuildContext context,
    PediatricsProvider provider,
    Patient? activePatient,
  ) {
    DateTime selectedDate = DateTime.now();
    final bDate = activePatient?.birthDate;

    double initMonths = 24.0;
    String initLabel = '2a';
    if (bDate != null) {
      final diffDays = selectedDate.difference(bDate).inDays;
      initMonths = (diffDays / 30.4375).clamp(0.0, 60.0);
      final y = initMonths ~/ 12;
      final m = (initMonths % 12).round();
      initLabel = y == 0 ? '${m}m' : (m == 0 ? '${y}a' : '${y}a ${m}m');
    }

    final dateController = TextEditingController(
      text:
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );
    final ageLabelController = TextEditingController(text: initLabel);
    final ageMonthsController = TextEditingController(
      text: initMonths.toStringAsFixed(1),
    );
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
            final mVal =
                double.tryParse(ageMonthsController.text) ?? initMonths;
            final liveWPerc = WhoStandards.calculatePercentile(
              wVal,
              mVal,
              'Peso',
            );
            final liveHPerc = WhoStandards.calculatePercentile(
              hVal,
              mVal,
              'Estatura',
            );

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.child_care, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Registrar Medición Antropométrica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de Fecha
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de la Medición',
                          suffixIcon: Icon(
                            Icons.calendar_month,
                            color: AppColors.primaryBlue,
                          ),
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
                              dateController.text =
                                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                              if (bDate != null) {
                                final diffDays =
                                    picked.difference(bDate).inDays;
                                final newM = (diffDays / 30.4375).clamp(
                                  0.0,
                                  60.0,
                                );
                                final y = newM ~/ 12;
                                final remM = (newM % 12).round();
                                ageMonthsController.text =
                                    newM.toStringAsFixed(1);
                                ageLabelController.text = y == 0
                                    ? '${remM}m'
                                    : (remM == 0 ? '${y}a' : '${y}a ${remM}m');
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                          labelText:
                              'Observaciones / Notas Clínicas (opcional)',
                          hintText:
                              'Desarrollo psicomotor, alimentación, alertas...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Vista previa en vivo de los percentiles calculados
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                                const Text(
                                  'Percentil Peso: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'P$liveWPerc (OMS)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Percentil Talla: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'P$liveHPerc (OMS)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  onPressed: () async {
                    final weight =
                        double.tryParse(weightController.text) ?? 14.0;
                    final height =
                        double.tryParse(heightController.text) ?? 92.0;
                    final head =
                        double.tryParse(headController.text) ?? 49.0;
                    final months =
                        (double.tryParse(ageMonthsController.text) ??
                                initMonths)
                            .clamp(0.0, 60.0);

                    final wPerc = WhoStandards.calculatePercentile(
                      weight,
                      months,
                      'Peso',
                    );
                    final hPerc = WhoStandards.calculatePercentile(
                      height,
                      months,
                      'Estatura',
                    );

                    final pid = activePatient?.id ??
                        provider.currentPatientId ??
                        widget.patientId ??
                        8;
                    final newRecord = GrowthRecord(
                      id: null,
                      patientId: pid,
                      date: selectedDate,
                      ageLabel: ageLabelController.text.isNotEmpty
                          ? ageLabelController.text
                          : '${months.toInt()}m',
                      ageMonths: months,
                      weightKg: weight,
                      weightPercentile: wPerc,
                      heightCm: height,
                      heightPercentile: hPerc,
                      headCircumferenceCm: head,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    final ok = await provider.addRecord(
                      newRecord,
                      patientId: pid,
                    );
                    nav.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Nueva medición antropométrica guardada correctamente.'
                              : 'Aviso: Se guardó localmente.',
                        ),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.warning,
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

  void _showEditMeasurementDialog(
    BuildContext context,
    GrowthRecord record,
    PediatricsProvider provider,
    Patient? activePatient,
  ) {
    DateTime selectedDate = record.date;
    final bDate = activePatient?.birthDate;

    final dateController = TextEditingController(
      text:
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );
    final ageLabelController = TextEditingController(text: record.ageLabel);
    final ageMonthsController = TextEditingController(
      text: record.ageMonths.toStringAsFixed(1),
    );
    final weightController = TextEditingController(
      text: record.weightKg.toString(),
    );
    final heightController = TextEditingController(
      text: record.heightCm.toString(),
    );
    final headController = TextEditingController(
      text: record.headCircumferenceCm.toString(),
    );
    final notesController = TextEditingController(
      text: record.notes ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final wVal =
                double.tryParse(weightController.text) ?? record.weightKg;
            final hVal =
                double.tryParse(heightController.text) ?? record.heightCm;
            final mVal =
                double.tryParse(ageMonthsController.text) ?? record.ageMonths;
            final liveWPerc = WhoStandards.calculatePercentile(
              wVal,
              mVal,
              'Peso',
            );
            final liveHPerc = WhoStandards.calculatePercentile(
              hVal,
              mVal,
              'Estatura',
            );

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Modificar Medición Pediátrica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Modifique los datos de somatometría del paciente. Los percentiles OMS se recalcularán automáticamente en tiempo real.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de Fecha
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de la Medición',
                          suffixIcon: Icon(
                            Icons.calendar_month,
                            color: AppColors.primaryBlue,
                          ),
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
                              dateController.text =
                                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                              if (bDate != null) {
                                final diffDays =
                                    picked.difference(bDate).inDays;
                                final newM = (diffDays / 30.4375).clamp(
                                  0.0,
                                  60.0,
                                );
                                final y = newM ~/ 12;
                                final remM = (newM % 12).round();
                                ageMonthsController.text =
                                    newM.toStringAsFixed(1);
                                ageLabelController.text = y == 0
                                    ? '${remM}m'
                                    : (remM == 0 ? '${y}a' : '${y}a ${remM}m');
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                          labelText:
                              'Observaciones / Notas Clínicas (opcional)',
                          hintText:
                              'Desarrollo psicomotor, alimentación, alertas...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Vista previa en vivo de los percentiles calculados
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                                const Text(
                                  'Percentil Peso: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'P$liveWPerc (OMS)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Percentil Talla: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'P$liveHPerc (OMS)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  onPressed: () async {
                    final weight =
                        double.tryParse(weightController.text) ??
                            record.weightKg;
                    final height =
                        double.tryParse(heightController.text) ??
                            record.heightCm;
                    final head = double.tryParse(headController.text) ??
                        record.headCircumferenceCm;
                    final months =
                        (double.tryParse(ageMonthsController.text) ??
                                record.ageMonths)
                            .clamp(0.0, 60.0);

                    final wPerc = WhoStandards.calculatePercentile(
                      weight,
                      months,
                      'Peso',
                    );
                    final hPerc = WhoStandards.calculatePercentile(
                      height,
                      months,
                      'Estatura',
                    );

                    final updatedRecord = GrowthRecord(
                      id: record.id,
                      patientId: record.patientId,
                      date: selectedDate,
                      ageLabel: ageLabelController.text.isNotEmpty
                          ? ageLabelController.text
                          : '${months.toInt()}m',
                      ageMonths: months,
                      weightKg: weight,
                      weightPercentile: wPerc,
                      heightCm: height,
                      heightPercentile: hPerc,
                      headCircumferenceCm: head,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    final ok = await provider.updateRecord(updatedRecord);
                    nav.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Medición antropométrica modificada y sincronizada correctamente.'
                              : 'Aviso: No se pudo sincronizar la modificación.',
                        ),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.warning,
                      ),
                    );
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFullHistoryDialog(
    BuildContext context,
    List<GrowthRecord> records,
    PediatricsProvider provider,
    Patient? activePatient,
  ) {
    final patientName = activePatient?.fullName ?? 'Paciente Pediátrico';
    final patientCode = activePatient?.patientCode.isNotEmpty == true
        ? '#${activePatient!.patientCode}'
        : '#P-8472';
    final gender = activePatient?.gender ?? 'Masculino';
    final ageText = formatPediatricAge(activePatient?.birthDate);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial Antropométrico ($patientName)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
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
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}',
                        ),
                      ),
                      DataCell(
                        Text(
                          r.ageLabel.isNotEmpty
                              ? r.ageLabel
                              : '${r.ageMonths.toInt()}m',
                        ),
                      ),
                      DataCell(Text('${r.weightKg} kg')),
                      DataCell(_buildPercentileBadge(r.weightPercentile)),
                      DataCell(Text('${r.heightCm.toStringAsFixed(1)} cm')),
                      DataCell(_buildPercentileBadge(r.heightPercentile)),
                      DataCell(
                        Text('${r.headCircumferenceCm.toStringAsFixed(1)} cm'),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              tooltip: 'Modificar medición',
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _showEditMeasurementDialog(
                                  context,
                                  r,
                                  provider,
                                  activePatient,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.danger,
                              ),
                              tooltip: 'Eliminar medición',
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _confirmDeleteMeasurement(context, r, provider);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
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

// ══════════════════════════════════════════════════════════════════════════
// LIENZO ADAPTATIVO CON CATMULL-ROM SPLINE Y ESCALAS DINÁMICAS OMS
// ══════════════════════════════════════════════════════════════════════════

class _AdaptiveWhoChartPainter extends CustomPainter {
  final List<GrowthRecord> records;
  final String selectedMetric;
  final int selectedIndex;
  final GrowthChartLayout layout;

  _AdaptiveWhoChartPainter({
    required this.records,
    required this.selectedMetric,
    required this.selectedIndex,
    required this.layout,
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

  /// Trazo de franja sombreada de normalidad entre P97 y P3
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
    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1;

    final axisTextPaint = TextPainter(textDirection: TextDirection.ltr);

    final bool isWeight = selectedMetric.contains('Peso');
    final bool isHeight = selectedMetric.contains('Estatura');

    // 1. Dibujar líneas y etiquetas del eje Y (5 intervalos claros con unidades)
    const int yDivisions = 5;
    for (int i = 0; i <= yDivisions; i++) {
      final val = layout.yMin + i * ((layout.yMax - layout.yMin) / yDivisions);
      final y = layout.getYPixel(val);

      canvas.drawLine(
        Offset(layout.paddingLeft, y),
        Offset(size.width - layout.paddingRight, y),
        gridPaint,
      );

      final label = isWeight
          ? '${val.round()} kg'
          : (isHeight ? '${val.round()} cm' : '${val.round()} cm');

      axisTextPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(canvas, Offset(8, y - 6));
    }

    // 2. Dibujar líneas y etiquetas del eje X según el rango máximo de meses
    List<double> xTicks;
    List<String> xLabels;

    if (layout.maxMonths <= 24.0) {
      xTicks = [0, 3, 6, 9, 12, 18, 24];
      xLabels = ['Nacim.', '3m', '6m', '9m', '12m (1a)', '18m', '24m (2a)'];
    } else if (layout.maxMonths <= 36.0) {
      xTicks = [0, 6, 12, 18, 24, 30, 36];
      xLabels = [
        'Nacim.',
        '6m',
        '12m (1a)',
        '18m',
        '24m (2a)',
        '30m',
        '36m (3a)',
      ];
    } else {
      xTicks = [0, 12, 24, 36, 48, 60];
      xLabels = ['Nacim.', '1 año', '2 años', '3 años', '4 años', '5 años'];
    }

    for (int i = 0; i < xTicks.length; i++) {
      final m = xTicks[i];
      final x = layout.getXPixel(m);

      canvas.drawLine(
        Offset(x, layout.paddingTop),
        Offset(x, size.height - layout.paddingBottom),
        gridPaint,
      );

      axisTextPaint.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(
        canvas,
        Offset(
          x - (i == 0 ? 0 : (i == xLabels.length - 1 ? 28 : 16)),
          size.height - layout.paddingBottom + 8,
        ),
      );
    }

    // 3. Generar curvas de percentiles OMS interpoladas hasta maxMonths
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

    final p3Offsets = <Offset>[];
    final p50Offsets = <Offset>[];
    final p97Offsets = <Offset>[];

    // Muestreo denso cada 1.5 meses para curvas matemáticamente continuas y sedosas
    final double stepMonth = layout.maxMonths <= 24 ? 1.0 : 2.0;
    for (double m = 0; m <= layout.maxMonths; m += stepMonth) {
      final x = layout.getXPixel(m);
      p3Offsets.add(Offset(x, layout.getYPixel(WhoStandards.interpolate(p3List, m))));
      p50Offsets.add(Offset(x, layout.getYPixel(WhoStandards.interpolate(p50List, m))));
      p97Offsets.add(Offset(x, layout.getYPixel(WhoStandards.interpolate(p97List, m))));
    }
    // Asegurar punto final exacto en maxMonths
    final xEnd = layout.getXPixel(layout.maxMonths);
    p3Offsets.add(Offset(xEnd, layout.getYPixel(WhoStandards.interpolate(p3List, layout.maxMonths))));
    p50Offsets.add(Offset(xEnd, layout.getYPixel(WhoStandards.interpolate(p50List, layout.maxMonths))));
    p97Offsets.add(Offset(xEnd, layout.getYPixel(WhoStandards.interpolate(p97List, layout.maxMonths))));

    // A. Franja sombreada de normalidad OMS (entre P3 y P97)
    final bandPath = buildBand(p97Offsets, p3Offsets);
    final bandPaint = Paint()
      ..color = const Color(0x1810B981) // Verde esmeralda suave al 9%
      ..style = PaintingStyle.fill;
    canvas.drawPath(bandPath, bandPaint);

    // B. Curvas de Límites P3 y P97 (Ámbar suave clínico)
    final pBoundsPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(buildSpline(p3Offsets), pBoundsPaint);
    canvas.drawPath(buildSpline(p97Offsets), pBoundsPaint);

    // C. Curva P50 OMS Mediana (Verde Esmeralda sólido de referencia)
    final p50Paint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(buildSpline(p50Offsets), p50Paint);

    // Etiquetas sutiles al final de las curvas OMS
    _drawCurveEndTag(canvas, p97Offsets.last, 'P97', const Color(0xFFF59E0B));
    _drawCurveEndTag(canvas, p50Offsets.last, 'P50', const Color(0xFF10B981));
    _drawCurveEndTag(canvas, p3Offsets.last, 'P3', const Color(0xFFF59E0B));

    // 4. Trayectoria y mediciones del paciente
    if (records.isNotEmpty) {
      final sorted = List<GrowthRecord>.from(records)
        ..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
      final patientOffsets = <Offset>[];

      for (final r in sorted) {
        final val = isWeight
            ? r.weightKg
            : (isHeight ? r.heightCm : r.headCircumferenceCm);
        patientOffsets.add(Offset(layout.getXPixel(r.ageMonths), layout.getYPixel(val)));
      }

      // Línea continua conectando mediciones reales del paciente
      if (patientOffsets.length >= 2) {
        final patientLinePaint = Paint()
          ..color = AppColors.primaryBlue
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(buildSpline(patientOffsets), patientLinePaint);
      }

      final activeRecord = (selectedIndex >= 0 && selectedIndex < records.length)
          ? records[selectedIndex]
          : null;

      // Marcadores circulares para cada control
      for (int i = 0; i < sorted.length; i++) {
        final pt = patientOffsets[i];
        final r = sorted[i];
        final isSelected = activeRecord != null && r.id == activeRecord.id;

        if (isSelected) {
          // Doble anillo luminoso y punto resaltado
          canvas.drawCircle(
            pt,
            14,
            Paint()..color = AppColors.primaryBlue.withValues(alpha: 0.22),
          );
          canvas.drawCircle(pt, 8, Paint()..color = AppColors.primaryBlue);
          canvas.drawCircle(pt, 4, Paint()..color = Colors.white);

          // Píldora de valor encima del punto seleccionado
          final textVal = isWeight
              ? '${r.weightKg} kg'
              : (isHeight ? '${r.heightCm.toStringAsFixed(1)} cm' : '${r.headCircumferenceCm.toStringAsFixed(1)} cm');
          _drawPointBadge(canvas, pt, textVal);
        } else {
          canvas.drawCircle(pt, 6, Paint()..color = Colors.white);
          canvas.drawCircle(
            pt,
            6,
            Paint()
              ..color = AppColors.primaryBlue
              ..strokeWidth = 2.4
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  void _drawCurveEndTag(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx + 4, pos.dy - 6));
  }

  void _drawPointBadge(Canvas canvas, Offset pt, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlue,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final badgeRect = Rect.fromCenter(
      center: Offset(pt.dx, pt.dy - 22),
      width: tp.width + 12,
      height: tp.height + 6,
    );

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(4));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.primaryBlue.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    tp.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 3));
  }

  @override
  bool shouldRepaint(covariant _AdaptiveWhoChartPainter oldDelegate) {
    return true;
  }
}
