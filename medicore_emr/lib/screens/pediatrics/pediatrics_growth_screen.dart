import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/growth_record.dart';
import '../../providers/clinical_providers.dart';
import '../../services/pdf_export_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/breadcrumb.dart';

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
      int pid = widget.patientId ?? 0;
      if (pid <= 0) {
        try {
          final res = await SupabaseService().getPatients(perPage: 1);
          if (res.isNotEmpty && res.first.id != null) {
            pid = res.first.id!;
          }
        } catch (_) {}
      }
      if (mounted && pid > 0) {
        context.read<PediatricsProvider>().loadGrowthData(pid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PediatricsProvider>(
      builder: (context, provider, _) {
        final records = provider.records;
        final selectedMetric = provider.selectedMetric;

        // Asegurar que el índice seleccionado no quede fuera de rango
        if (records.isNotEmpty && _selectedPointIndex >= records.length) {
          _selectedPointIndex = 0;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb de navegación
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  const BreadcrumbItem(label: 'Mateo García (ID: P-8472)'),
                  const BreadcrumbItem(label: 'Curvas de Crecimiento'),
                ],
              ),
              const SizedBox(height: 20),

              // Encabezado con selector de métrica y botón de PDF
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gráficas de Crecimiento (OMS)',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mateo García • Masculino • 2 Años 4 Meses (Exp. P-8472)',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Selector desplegable de métricas OMS
                      Container(
                        width: 260,
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
                              patientName: 'Mateo García',
                              patientCode: 'P-8472',
                              gender: 'Masculino',
                              ageText: '2 Años 4 Meses',
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
                        label: const Text('Exportar Gráfica PDF'),
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
                                  _legendPill(AppColors.success, '— P50 (Mediana OMS)'),
                                  const SizedBox(width: 12),
                                  _legendPill(AppColors.warning, '— P3 / P97 Límites'),
                                  const SizedBox(width: 12),
                                  _legendPill(AppColors.primaryBlue, '● Mediciones Paciente'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Custom Painter para curvas y puntos
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
                                  ),
                                ),
                                // Tooltip interactivo con datos de la medición seleccionada
                                if (records.isNotEmpty && _selectedPointIndex < records.length)
                                  Positioned(
                                    top: 60,
                                    left: 100,
                                    child: _buildTooltip(records[_selectedPointIndex], selectedMetric),
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
                                const Text(
                                  'Historial de Mediciones',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Tooltip(
                                  message: 'Registrar nueva medición antropométrica',
                                  child: IconButton.filledTonal(
                                    icon: const Icon(Icons.add, size: 20, color: AppColors.primaryBlue),
                                    onPressed: () => _showAddMeasurementDialog(context, provider),
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
                                Expanded(flex: 3, child: Text('Fecha\n(Edad)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Peso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Estatura', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                Expanded(flex: 1, child: Text('PC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              ],
                            ),
                          ),

                          // Filas de medidas
                          ...records.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final r = entry.value;
                            final isSelected = _selectedPointIndex == idx;
                            return InkWell(
                              onTap: () => setState(() => _selectedPointIndex = idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : null,
                                  border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
                                ),
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
                                          Text(r.ageLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${r.weightKg} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                          Text('P${r.weightPercentile}', style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${r.heightCm.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                          Text('P${r.heightPercentile}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text('${r.headCircumferenceCm.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 12),
                          // Enlace para ver historial completo en diálogo
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextButton.icon(
                              onPressed: () => _showFullHistoryDialog(context, records, provider),
                              icon: const Icon(Icons.table_chart_outlined, size: 16),
                              label: const Text('Ver Historial Detallado y Percentiles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                            ),
                          ),
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

  Widget _legendPill(Color color, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }

  Widget _buildTooltip(GrowthRecord record, String metric) {
    String metricLabel;
    if (metric.contains('Peso')) {
      metricLabel = '${record.weightKg} kg (Percentil ${record.weightPercentile})';
    } else if (metric.contains('Estatura')) {
      metricLabel = '${record.heightCm.toStringAsFixed(1)} cm (Percentil ${record.heightPercentile})';
    } else {
      metricLabel = 'PC: ${record.headCircumferenceCm.toStringAsFixed(1)} cm (Normocéfalo)';
    }

    final monthName = _spanishMonths[record.date.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metricLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white),
          ),
          const SizedBox(height: 2),
          Text(
            '${record.date.day} $monthName, ${record.date.year} (${record.ageLabel})',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Diálogo para agregar una nueva medición pediátrica de crecimiento
  void _showAddMeasurementDialog(BuildContext context, PediatricsProvider provider) {
    DateTime selectedDate = DateTime.now();
    final dateController = TextEditingController(text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}');
    final ageLabelController = TextEditingController(text: '2a 6m');
    final ageMonthsController = TextEditingController(text: '30');
    final weightController = TextEditingController(text: '14.8');
    final heightController = TextEditingController(text: '94.0');
    final headController = TextEditingController(text: '49.5');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.child_care, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Registrar Nueva Medición Antropométrica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ingrese los valores de la somatometría pediátrica para calcular automáticamente el percentil OMS.',
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
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              dateController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
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
                                labelText: 'Etiqueta Edad (ej: 2a 6m)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: ageMonthsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Edad en Meses (ej: 30)',
                                border: OutlineInputBorder(),
                              ),
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
                              ),
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
                              ),
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
                    final months = double.tryParse(ageMonthsController.text) ?? 28.0;

                    // Cálculo aproximado de percentiles para niños varones OMS
                    int wPerc = 50;
                    if (weight >= 15.0) wPerc = 75;
                    if (weight >= 16.5) wPerc = 90;
                    if (weight <= 12.0) wPerc = 25;
                    if (weight <= 10.5) wPerc = 10;

                    int hPerc = 50;
                    if (height >= 95.0) hPerc = 75;
                    if (height <= 85.0) hPerc = 25;

                    final pid = provider.currentPatientId ?? widget.patientId ?? 1;
                    final newRecord = GrowthRecord(
                      id: DateTime.now().millisecondsSinceEpoch,
                      patientId: pid,
                      date: selectedDate,
                      ageLabel: ageLabelController.text.isNotEmpty ? ageLabelController.text : '${months.toInt()}m',
                      ageMonths: months,
                      weightKg: weight,
                      weightPercentile: wPerc,
                      heightCm: height,
                      heightPercentile: hPerc,
                      headCircumferenceCm: head,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    await provider.addRecord(newRecord, patientId: pid);
                    nav.pop();

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Nueva medición antropométrica registrada correctamente.'),
                        backgroundColor: AppColors.success,
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
  void _showFullHistoryDialog(BuildContext context, List<GrowthRecord> records, PediatricsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Historial Antropométrico Completo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  PdfExportService.exportPediatricGrowthPdf(
                    context: context,
                    patientName: 'Mateo García',
                    patientCode: 'P-8472',
                    gender: 'Masculino',
                    ageText: '2 Años 4 Meses',
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
            width: 700,
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
                ],
                rows: records.map((r) {
                  return DataRow(cells: [
                    DataCell(Text('${r.date.day}/${r.date.month}/${r.date.year}')),
                    DataCell(Text(r.ageLabel)),
                    DataCell(Text('${r.weightKg} kg')),
                    DataCell(Text('P${r.weightPercentile}')),
                    DataCell(Text('${r.heightCm.toStringAsFixed(1)} cm')),
                    DataCell(Text('P${r.heightPercentile}')),
                    DataCell(Text('${r.headCircumferenceCm.toStringAsFixed(1)} cm')),
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

// ─── Lienzo Dinámico de Gráficas de Crecimiento OMS (Peso, Talla, Perímetro) ───
class _WhoGrowthChartPainter extends CustomPainter {
  final List<GrowthRecord> records;
  final String selectedMetric;

  _WhoGrowthChartPainter({
    required this.records,
    required this.selectedMetric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 45;
    const double paddingBottom = 30;
    final double chartWidth = size.width - paddingLeft - 20;
    final double chartHeight = size.height - paddingBottom - 20;

    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1;

    final axisTextPaint = TextPainter(textDirection: TextDirection.ltr);

    // Configuración según la métrica seleccionada
    final bool isWeight = selectedMetric.contains('Peso');
    final bool isHeight = selectedMetric.contains('Estatura');

    double yMin, yMax;
    List<String> yLabels;

    if (isWeight) {
      yMin = 0.0;
      yMax = 16.0;
      yLabels = ['0kg', '2kg', '4kg', '6kg', '8kg', '10kg', '12kg', '14kg', '16kg'];
    } else if (isHeight) {
      yMin = 40.0;
      yMax = 120.0;
      yLabels = ['40cm', '50cm', '60cm', '70cm', '80cm', '90cm', '100cm', '110cm', '120cm'];
    } else {
      // Perímetro Cefálico
      yMin = 30.0;
      yMax = 55.0;
      yLabels = ['30cm', '35cm', '40cm', '45cm', '50cm', '55cm'];
    }

    // Dibujar líneas y etiquetas del eje Y
    for (int i = 0; i < yLabels.length; i++) {
      final y = size.height - paddingBottom - (i * (chartHeight / (yLabels.length - 1)));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - 20, y), gridPaint);

      axisTextPaint.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(canvas, Offset(5, y - 6));
    }

    // Dibujar líneas y etiquetas del eje X (0 a 5 años)
    const xLabels = ['Nacim', '1 año', '2 años', '3 años', '4 años', '5 años'];
    for (int i = 0; i < xLabels.length; i++) {
      final x = paddingLeft + (i * (chartWidth / (xLabels.length - 1)));
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - paddingBottom), gridPaint);

      axisTextPaint.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
      axisTextPaint.layout();
      axisTextPaint.paint(canvas, Offset(x - 14, size.height - paddingBottom + 8));
    }

    // Función auxiliar para convertir un valor numérico Y a coordenada en píxeles
    double getYPixel(double val) {
      final normalized = ((val - yMin) / (yMax - yMin)).clamp(0.0, 1.0);
      return size.height - paddingBottom - (normalized * chartHeight);
    }

    // 1. Curva Percentil 50 de la OMS (Verde)
    final p50Paint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final p50Path = Path();
    if (isWeight) {
      p50Path.moveTo(paddingLeft, getYPixel(3.3));
      p50Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(12.2),
        size.width - 20,
        getYPixel(18.3),
      );
    } else if (isHeight) {
      p50Path.moveTo(paddingLeft, getYPixel(50.0));
      p50Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(87.0),
        size.width - 20,
        getYPixel(110.0),
      );
    } else {
      p50Path.moveTo(paddingLeft, getYPixel(34.5));
      p50Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(47.5),
        size.width - 20,
        getYPixel(51.0),
      );
    }
    canvas.drawPath(p50Path, p50Paint);

    // 2. Curva Percentiles Límites OMS P3 / P97 (Amarillo / Naranja)
    final pBoundsPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final p97Path = Path();
    if (isWeight) {
      p97Path.moveTo(paddingLeft, getYPixel(4.2));
      p97Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(14.0),
        size.width - 20,
        getYPixel(20.0),
      );
    } else if (isHeight) {
      p97Path.moveTo(paddingLeft, getYPixel(54.0));
      p97Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(93.0),
        size.width - 20,
        getYPixel(116.0),
      );
    } else {
      p97Path.moveTo(paddingLeft, getYPixel(37.0));
      p97Path.quadraticBezierTo(
        paddingLeft + chartWidth * 0.4,
        getYPixel(49.5),
        size.width - 20,
        getYPixel(53.0),
      );
    }
    canvas.drawPath(p97Path, pBoundsPaint);

    // 3. Puntos y Línea de Mediciones del Paciente (Azul Primario)
    if (records.isNotEmpty) {
      final patientLinePaint = Paint()
        ..color = AppColors.primaryBlue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final pointFillPaint = Paint()..color = AppColors.white;
      final pointStrokePaint = Paint()
        ..color = AppColors.primaryBlue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final patientPath = Path();
      final points = <Offset>[];

      // Ordenar cronológicamente
      final sorted = List<GrowthRecord>.from(records)..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
      for (int i = 0; i < sorted.length; i++) {
        final r = sorted[i];
        final x = paddingLeft + ((r.ageMonths / 60.0).clamp(0.0, 1.0) * chartWidth);

        double val;
        if (isWeight) {
          val = r.weightKg;
        } else if (isHeight) {
          val = r.heightCm;
        } else {
          val = r.headCircumferenceCm;
        }

        final y = getYPixel(val);
        points.add(Offset(x, y));

        if (i == 0) {
          patientPath.moveTo(x, y);
        } else {
          patientPath.lineTo(x, y);
        }
      }

      canvas.drawPath(patientPath, patientLinePaint);

      for (final pt in points) {
        canvas.drawCircle(pt, 5, pointFillPaint);
        canvas.drawCircle(pt, 5, pointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhoGrowthChartPainter oldDelegate) {
    return oldDelegate.selectedMetric != selectedMetric || oldDelegate.records.length != records.length;
  }
}
