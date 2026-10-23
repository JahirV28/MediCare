import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/pdf_export_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/breadcrumb.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ReportsScreen({super.key, this.onBack});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseService _api = SupabaseService();
  String? _selectedReport;
  bool _isGenerating = false;
  bool _reportGenerated = false;
  DateTimeRange? _dateRange;

  final List<_ReportTemplate> _templates = [
    _ReportTemplate(
      icon: Icons.people_outline,
      title: 'Pacientes Nuevos',
      description: 'Registro de pacientes ingresados en el período seleccionado.',
      color: AppColors.primaryBlue,
    ),
    _ReportTemplate(
      icon: Icons.medical_information_outlined,
      title: 'Consultas Realizadas',
      description: 'Detalle de consultas SOAP, diagnósticos y tratamientos.',
      color: AppColors.success,
    ),
    _ReportTemplate(
      icon: Icons.attach_money,
      title: 'Ingresos por Período',
      description: 'Resumen financiero de cobros, pagos y balances.',
      color: AppColors.warning,
    ),
    _ReportTemplate(
      icon: Icons.medical_services_outlined,
      title: 'Procedimientos',
      description: 'Lista de procedimientos realizados por tipo y especialidad.',
      color: AppColors.danger,
    ),
    _ReportTemplate(
      icon: Icons.child_care_outlined,
      title: 'Control Pediátrico',
      description: 'Seguimiento de crecimiento y vacunación de pacientes pediátricos.',
      color: const Color(0xFF8B5CF6),
    ),
    _ReportTemplate(
      icon: Icons.calendar_today_outlined,
      title: 'Citas y Asistencia',
      description: 'Estadísticas de citas: confirmadas, canceladas y ausencias.',
      color: const Color(0xFF06B6D4),
    ),
  ];

  List<String> _reportHeaders = [];
  List<List<String>> _reportRows = [];
  double? _reportTotal;
  int _recordCount = 0;

  Future<void> _loadReport() async {
    if (_selectedReport == null) return;
    setState(() {
      _isGenerating = true;
      _reportGenerated = false;
    });

    final now = DateTime.now();
    final start = _dateRange?.start ?? DateTime(now.year, now.month, 1);
    final end = _dateRange?.end ?? now;

    try {
      final res = await _api.generateReportData(
        reportTitle: _selectedReport!,
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      setState(() {
        _reportHeaders = List<String>.from(res['headers'] ?? []);
        _reportRows = (res['rows'] as List? ?? [])
            .map((r) => (r as List).map((c) => c?.toString() ?? '').toList())
            .toList();
        _reportTotal = (res['total'] as num?)?.toDouble();
        _recordCount = (res['count'] as num?)?.toInt() ?? _reportRows.length;
        _isGenerating = false;
        _reportGenerated = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportHeaders = ['#', 'Fecha', 'Paciente', 'Detalle', 'Estado'];
        _reportRows = [];
        _reportTotal = null;
        _recordCount = 0;
        _isGenerating = false;
        _reportGenerated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Breadcrumb(
            items: [
              BreadcrumbItem(label: 'Panel', onTap: widget.onBack),
              const BreadcrumbItem(label: 'Reportes'),
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
                  Text('Reportes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Genere reportes detallados de la actividad de su clínica.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
              // Date range picker
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange ?? DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 30)),
                      end: DateTime.now(),
                    ),
                  );
                  if (range != null) {
                    setState(() => _dateRange = range);
                    if (_selectedReport != null) {
                      _loadReport();
                    }
                  }
                },
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _dateRange != null
                      ? '${_dateRange!.start.day}/${_dateRange!.start.month} — ${_dateRange!.end.day}/${_dateRange!.end.month}'
                      : 'Seleccionar Fechas',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Report templates grid
          _buildTemplateGrid(),

          if (_reportGenerated) ...[
            const SizedBox(height: 24),
            _buildGeneratedReport(),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _templates.map((t) {
        final isSelected = _selectedReport == t.title;
        return InkWell(
          onTap: () async {
            setState(() {
              _selectedReport = t.title;
            });
            await _loadReport();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 200 - 48 - 32) / 3 - 12,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? t.color : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: t.color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(t.icon, size: 22, color: t.color),
                    ),
                    if (isSelected && _isGenerating)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                      )
                    else if (isSelected && _reportGenerated)
                      const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  t.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  t.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? t.color.withValues(alpha: 0.1) : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      isSelected ? 'Seleccionado' : 'Generar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? t.color : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGeneratedReport() {
    final rangeText = _dateRange != null
        ? '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}'
        : 'Mes Actual';

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
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 20, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Reporte: $_selectedReport',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_recordCount registros encontrados${_reportTotal != null ? ' | Total: \$${_reportTotal!.toStringAsFixed(2)}' : ''} | Generado: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _reportRows.isEmpty
                        ? null
                        : () async {
                            await PdfExportService.exportReportPdf(
                              context: context,
                              reportTitle: 'Reporte: $_selectedReport',
                              dateRangeText: rangeText,
                              headers: [_reportHeaders],
                              rows: _reportRows,
                            );
                          },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Imprimir', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _reportRows.isEmpty
                        ? null
                        : () async {
                            await PdfExportService.exportReportPdf(
                              context: context,
                              reportTitle: 'Reporte: $_selectedReport',
                              dateRangeText: rangeText,
                              headers: [_reportHeaders],
                              rows: _reportRows,
                            );
                          },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('Exportar PDF', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          if (_reportHeaders.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: _reportHeaders.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final title = entry.value;
                  final flex = idx == 0 ? 1 : (idx == 1 ? 2 : (idx == 2 ? 3 : 2));
                  return Expanded(
                    flex: flex,
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_reportRows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 36, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  const Text(
                    'No se encontraron registros en el período seleccionado.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ..._reportRows.map((row) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
                  child: Row(
                    children: row.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cell = entry.value;
                      final flex = idx == 0 ? 1 : (idx == 1 ? 2 : (idx == 2 ? 3 : 2));
                      final isBold = idx == 2 || (idx == row.length - 1 && cell.startsWith('\$'));
                      return Expanded(
                        flex: flex,
                        child: Text(
                          cell,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                            color: idx == 0
                                ? AppColors.textHint
                                : (isBold ? AppColors.textPrimary : AppColors.textSecondary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )),
        ],
      ),
    );
  }
}

class _ReportTemplate {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _ReportTemplate({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
