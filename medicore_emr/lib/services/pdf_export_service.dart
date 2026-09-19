import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/growth_record.dart';
import '../models/prescription.dart';

class PdfExportService {
  /// Exporta el reporte pediátrico de crecimiento OMS en PDF profesional
  static Future<void> exportPediatricGrowthPdf({
    required BuildContext context,
    required String patientName,
    required String patientCode,
    required String gender,
    required String ageText,
    required List<GrowthRecord> records,
    required String activeMetric,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Membrete Clínica
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MEDICORE EMR - CLÍNICA PEDIÁTRICA',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Departamento de Pediatría y Desarrollo Infantil',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Av. Médica 1050, Suite 300 • Tel: +52 (55) 8800-4000',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.blue300),
                      ),
                      child: pw.Text(
                        'REPORTE DE CRECIMIENTO OMS',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha de emisión: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Datos del Paciente
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoField('Paciente:', patientName),
                        pw.SizedBox(height: 4),
                        _pdfInfoField('Expediente:', patientCode),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoField('Sexo:', gender),
                        pw.SizedBox(height: 4),
                        _pdfInfoField('Edad cronológica:', ageText),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoField('Patrón de referencia:', 'OMS (0-5 Años)'),
                        pw.SizedBox(height: 4),
                        _pdfInfoField('Métrica activa:', activeMetric),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Resumen de Última Medición
            if (records.isNotEmpty) ...[
              pw.Text(
                'Última Evaluación Antropométrica',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _pdfMetricPill('Peso Actual', '${records.first.weightKg} kg', 'P${records.first.weightPercentile} (Normal)', PdfColors.green700),
                  pw.SizedBox(width: 10),
                  _pdfMetricPill('Estatura Actual', '${records.first.heightCm.toStringAsFixed(1)} cm', 'P${records.first.heightPercentile} (Normal)', PdfColors.blue700),
                  pw.SizedBox(width: 10),
                  _pdfMetricPill('Perímetro Cefálico', '${records.first.headCircumferenceCm.toStringAsFixed(1)} cm', 'Normocéfalo', PdfColors.orange700),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Tabla Histórica de Crecimiento
            pw.Text(
              'Historial Cronológico de Mediciones Antropométricas',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Cabecera
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    _pdfTableCell('Fecha', isHeader: true),
                    _pdfTableCell('Edad', isHeader: true),
                    _pdfTableCell('Peso (kg)', isHeader: true),
                    _pdfTableCell('Percentil Peso', isHeader: true),
                    _pdfTableCell('Estatura (cm)', isHeader: true),
                    _pdfTableCell('Percentil Talla', isHeader: true),
                    _pdfTableCell('Perím. Cefálico (cm)', isHeader: true),
                  ],
                ),
                // Filas de datos
                ...records.map((r) {
                  return pw.TableRow(
                    children: [
                      _pdfTableCell('${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}'),
                      _pdfTableCell(r.ageLabel),
                      _pdfTableCell('${r.weightKg} kg'),
                      _pdfTableCell('${r.weightPercentile}% (OMS)'),
                      _pdfTableCell('${r.heightCm.toStringAsFixed(1)} cm'),
                      _pdfTableCell('${r.heightPercentile}% (OMS)'),
                      _pdfTableCell('${r.headCircumferenceCm.toStringAsFixed(1)} cm'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Interpretación Médica y Recomendaciones
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Interpretación Médica y Observaciones:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'El paciente presenta un canal de crecimiento armónico de acuerdo con las curvas estándar de la Organización Mundial de la Salud (OMS). Desarrollo pondoestatural adecuado para edad y sexo.',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800, lineSpacing: 2),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Recomendación: Continuar con lactancia/alimentación complementaria balanceada, estimulación temprana y próximo control antropométrico programado en 3 meses.',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800, lineSpacing: 2),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 35),

            // Firma y Cédula
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 170, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 4),
                    pw.Text('Firma del Pediatra Responsable', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Dra. Elena Ramos - Pediatra Neonatóloga', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Céd. Prof. 8492041 / Reg. SSA 49204', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 170, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 4),
                    pw.Text('Sello de la Clínica Pediátrica', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('MediCore Health System', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Validación Digital EMR', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Crecimiento_${patientName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Exporta la receta médica oficial en PDF profesional
  static Future<void> exportPrescriptionPdf({
    required BuildContext context,
    required Prescription prescription,
    required List<PrescriptionItem> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Médico
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DR. ALEJANDRO RAMÍREZ S.',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text('Médico Cirujano y Partero • Medicina Interna', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text('Céd. Prof. 984120 • Reg. SSA 77412', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('MEDICORE EMR', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Folio: RX-00${prescription.id ?? 1024}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.blue900),
              pw.SizedBox(height: 6),

              // Datos del Paciente
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Paciente: ${prescription.patientName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Expediente: PT-${prescription.patientId}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Símbolo Rx
              pw.Text('Rx', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 8),

              // Lista de Medicamentos
              ...items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$idx. ${item.drugName} - ${item.dose}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '   Indicaciones: ${item.instructions ?? "Tomar ${item.dose} ${item.frequency.toLowerCase()} durante ${item.duration}."}',
                        style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),

              // Pie de Receta y Firma
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Próxima cita en 15 días o por urgencias.', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      pw.Text('Urgencias: 800-MEDICORE | www.medicore.com', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 0.8, color: PdfColors.grey600),
                      pw.SizedBox(height: 2),
                      pw.Text('Firma y Sello del Médico', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receta_Medica_${prescription.patientName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Exporta reportes clínicos o administrativos en PDF
  static Future<void> exportReportPdf({
    required BuildContext context,
    required String reportTitle,
    required String dateRangeText,
    required List<List<String>> headers,
    required List<List<String>> rows,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Encabezado
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MEDICORE EMR - SISTEMA HOSPITALARIO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('Reporte Oficial Generado', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('Generado: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.blue800),
            pw.SizedBox(height: 10),

            pw.Text(reportTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
            pw.SizedBox(height: 4),
            pw.Text('Período: $dateRangeText', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 14),

            // Tabla
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: headers.first.map((h) => _pdfTableCell(h, isHeader: true)).toList(),
                ),
                ...rows.map((row) {
                  return pw.TableRow(
                    children: row.map((c) => _pdfTableCell(c)).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Reporte emitido por el sistema MediCore EMR versión certificada.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${reportTitle.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _pdfInfoField(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        text: '$label ',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        children: [
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.normal, color: PdfColors.grey900),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfMetricPill(String title, String val, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: color.shade(0.3)),
          color: color.shade(0.05),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(val, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
            pw.Text(sub, style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
