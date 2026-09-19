import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/common/breadcrumb.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ReportsScreen({super.key, this.onBack});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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

  // Mock report data
  final List<_ReportRow> _mockReportData = [
    _ReportRow(id: '001', col1: '02 Ago 2026', col2: 'Ana García', col3: 'Consulta General', col4: '\$850'),
    _ReportRow(id: '002', col1: '03 Ago 2026', col2: 'Carlos López', col3: 'Control', col4: '\$500'),
    _ReportRow(id: '003', col1: '05 Ago 2026', col2: 'María Rodríguez', col3: 'Odontología', col4: '\$1,200'),
    _ReportRow(id: '004', col1: '07 Ago 2026', col2: 'Juan Perez', col3: 'Radiografía', col4: '\$600'),
    _ReportRow(id: '005', col1: '08 Ago 2026', col2: 'Laura Sánchez', col3: 'Pediatría', col4: '\$750'),
    _ReportRow(id: '006', col1: '10 Ago 2026', col2: 'Pedro Martínez', col3: 'Extracción', col4: '\$1,500'),
    _ReportRow(id: '007', col1: '12 Ago 2026', col2: 'Miguel Torres', col3: 'Laboratorio', col4: '\$2,300'),
    _ReportRow(id: '008', col1: '14 Ago 2026', col2: 'Sofía Herrera', col3: 'Consulta General', col4: '\$850'),
    _ReportRow(id: '009', col1: '15 Ago 2026', col2: 'Diego Ruiz', col3: 'Ortodoncia', col4: '\$3,500'),
    _ReportRow(id: '010', col1: '18 Ago 2026', col2: 'Valentina Díaz', col3: 'Control', col4: '\$500'),
  ];

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
              _isGenerating = true;
              _reportGenerated = false;
            });
            // Simulate report generation
            await Future.delayed(const Duration(milliseconds: 800));
            if (!mounted) return;
            setState(() {
              _isGenerating = false;
              _reportGenerated = true;
            });
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
                    '${_mockReportData.length} registros encontrados | Generado: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final rangeText = _dateRange != null
                          ? '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}'
                          : 'Mes Actual';
                      await PdfExportService.exportReportPdf(
                        context: context,
                        reportTitle: 'Reporte: $_selectedReport',
                        dateRangeText: rangeText,
                        headers: [
                          ['#', 'Fecha', 'Paciente', 'Concepto', 'Monto']
                        ],
                        rows: _mockReportData.map((r) => [r.id, r.col1, r.col2, r.col3, r.col4]).toList(),
                      );
                    },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Imprimir', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final rangeText = _dateRange != null
                          ? '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}'
                          : 'Mes Actual';
                      await PdfExportService.exportReportPdf(
                        context: context,
                        reportTitle: 'Reporte: $_selectedReport',
                        dateRangeText: rangeText,
                        headers: [
                          ['#', 'Fecha', 'Paciente', 'Concepto', 'Monto']
                        ],
                        rows: _mockReportData.map((r) => [r.id, r.col1, r.col2, r.col3, r.col4]).toList(),
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

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Fecha', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Paciente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Concepto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Monto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
          ),

          ..._mockReportData.map((r) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text(r.id, style: const TextStyle(fontSize: 12, color: AppColors.textHint))),
                    Expanded(flex: 2, child: Text(r.col1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    Expanded(flex: 3, child: Text(r.col2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    Expanded(flex: 3, child: Text(r.col3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    Expanded(flex: 2, child: Text(r.col4, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ],
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

class _ReportRow {
  final String id;
  final String col1;
  final String col2;
  final String col3;
  final String col4;

  const _ReportRow({
    required this.id,
    required this.col1,
    required this.col2,
    required this.col3,
    required this.col4,
  });
}
