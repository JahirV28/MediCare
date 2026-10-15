import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/prescription.dart';
import '../../providers/clinical_providers.dart';
import '../../providers/patient_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/common/breadcrumb.dart';

class PrescriptionBuilderScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PrescriptionBuilderScreen({super.key, this.onBack});

  @override
  State<PrescriptionBuilderScreen> createState() => _PrescriptionBuilderScreenState();
}

class _PrescriptionBuilderScreenState extends State<PrescriptionBuilderScreen> {
  final _drugController = TextEditingController();
  final _doseController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedFrequency = 'Cada 8 horas';
  final List<String> _frequencyOptions = [
    'Cada 6 horas',
    'Cada 8 horas',
    'Cada 12 horas',
    'Cada 24 horas',
    'Cada 24h (mañanas)',
    'Cada 24h (noches)',
    'Dosis única',
    'Según sea necesario (PRN)',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patient = context.read<PatientProvider>().selectedPatient;
      context.read<PrescriptionProvider>().loadPrescription(patientId: patient?.id);
    });
  }

  String _formatCurrentDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _drugController.dispose();
    _doseController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrescriptionProvider>(
      builder: (context, provider, _) {
        final prescription = provider.prescription;
        if (prescription == null && provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }

        final curPatient = context.watch<PatientProvider>().selectedPatient;
        final patientName = curPatient?.fullName ?? prescription?.patientName ?? "Paciente";
        final patientCode = curPatient?.patientCode ?? prescription?.patientCode ?? "-";
        final patientAge = curPatient?.age ?? prescription?.patientAge;
        final alerts = context.watch<PatientProvider>().allergyAlerts;
        final allergiesText = alerts.isNotEmpty
            ? alerts.map((a) => a.allergen).join(', ')
            : 'Sin Alergias Conocidas';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(label: patientName, onTap: widget.onBack),
                  const BreadcrumbItem(label: 'Nueva Receta'),
                ],
              ),
              const SizedBox(height: 20),

              // Title Header
              const Text(
                'Creador de Receta Médica',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure los medicamentos y dosis para el paciente actual.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Two columns: Left Builder + Right Live Rx Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── LEFT COLUMN: Patient Card + Add Drug + Added Drugs Table ───
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Patient Summary Card
                        Container(
                          padding: const EdgeInsets.all(20),
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
                                  Text(
                                    'Paciente: $patientName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.borderLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      'ID: $patientCode',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _infoSnippet('Edad', patientAge != null ? '$patientAge años' : '-'),
                                  const SizedBox(width: 32),
                                  _infoSnippet('Peso', prescription?.patientWeightKg != null ? '${prescription!.patientWeightKg!.toInt()} kg' : '-'),
                                  const SizedBox(width: 32),
                                  _infoSnippet(
                                    'Alergias',
                                    allergiesText,
                                    valueColor: alerts.isNotEmpty ? AppColors.danger : AppColors.success,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. Add Medication Form
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AÑADIR MEDICAMENTO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Drug search
                              const Text('Buscador de Fármacos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await SupabaseService().searchDrugs(textEditingValue.text);
                                },
                                onSelected: (String selection) {
                                  _drugController.text = selection;
                                },
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    onChanged: (val) => _drugController.text = val,
                                    decoration: InputDecoration(
                                      hintText: 'Ej: Amoxicilina, Paracetamol...',
                                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Dosis + Frecuencia + Duración
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Dosis
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Dosis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _doseController,
                                          decoration: InputDecoration(
                                            hintText: 'Ej: 1 pastilla',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Frecuencia
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Frecuencia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedFrequency,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                          ),
                                          items: _frequencyOptions.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                                          onChanged: (v) => setState(() => _selectedFrequency = v!),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Duración
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Duración', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _durationController,
                                          decoration: InputDecoration(
                                            hintText: 'Ej: 7 días',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Instrucciones Adicionales
                              const Text('Instrucciones Adicionales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _instructionsController,
                                decoration: InputDecoration(
                                  hintText: 'Ej: Tomar con alimentos',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Button Add
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: _handleAddDrug,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Añadir a la Receta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. Added Medications Table
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Text(
                                  'MEDICAMENTOS AÑADIDOS (${provider.items.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                color: AppColors.background,
                                child: const Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Nombre del Medicamento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('Dosis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('Frecuencia', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('Duración', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    SizedBox(width: 40),
                                  ],
                                ),
                              ),
                              // Rows
                              ...provider.items.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(item.drugName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                      Expanded(flex: 2, child: Text(item.dose, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                                      Expanded(flex: 2, child: Text(item.frequency, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                                      Expanded(flex: 2, child: Text(item.duration, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                                          onPressed: () => provider.removeItem(idx),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // ─── RIGHT COLUMN: Live Rx Document Preview + Print Button ───
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VISTA PREVIA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Paper Sheet Representation
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Clinic header
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.local_hospital, color: AppColors.white, size: 20),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                prescription?.clinicName ?? 'Clínica Sanitas Central',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlueDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prescription?.clinicAddress ?? 'Av. Principal 123, Ciudad • Tel: 555-0192',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              Text(
                                '${prescription?.doctorName ?? "Dr. Carlos Mendoza"} • ${prescription?.professionalLicense ?? "C.M. 45892"}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: AppColors.primaryBlue, thickness: 1.5),
                              const SizedBox(height: 12),

                              // Patient and Date Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Paciente:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        patientName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Fecha:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        _formatCurrentDate(prescription?.date ?? DateTime.now()),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Big Rx Symbol
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '℞',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontFamily: 'serif',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Medicines List
                              if (provider.items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Text('No hay medicamentos añadidos.', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                                )
                              else
                                ...provider.items.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.drugName,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.instructions ??
                                                  'Tomar ${item.dose} ${item.frequency.toLowerCase()} durante ${item.duration}.',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),

                              const SizedBox(height: 40),
                              // Doctor Signature Line
                              Container(
                                width: 180,
                                height: 1,
                                color: AppColors.border,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Firma y Sello del Médico',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Button: Print / PDF
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (provider.items.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Añada al menos un medicamento a la receta antes de generar o imprimir.'),
                                    backgroundColor: AppColors.warning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final pat = context.read<PatientProvider>().selectedPatient;
                              if (pat != null && pat.id != null) {
                                await provider.savePrescription(pat.id!);
                                if (!context.mounted) return;
                                await context.read<PatientProvider>().loadPatientDetail();
                              }

                              try {
                                final presToExport = (prescription ??
                                        Prescription(
                                          patientId: pat?.id ?? 0,
                                          patientName: pat?.fullName ?? 'Paciente',
                                          patientCode: pat?.patientCode ?? 'PT-000',
                                          date: DateTime.now(),
                                          clinicName: 'Clínica Sanitas Central',
                                          clinicAddress: 'Av. Principal 123, Ciudad • Tel: 555-0192',
                                          doctorName: 'Dr. Carlos Mendoza',
                                          items: provider.items,
                                        ))
                                    .copyWith(
                                  patientName: patientName,
                                  patientCode: patientCode,
                                  items: provider.items,
                                );

                                if (!context.mounted) return;
                                await PdfExportService.exportPrescriptionPdf(
                                  context: context,
                                  prescription: presToExport,
                                  items: provider.items,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Receta médica guardada y generada en PDF con éxito.'),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al generar PDF: $e'),
                                      backgroundColor: AppColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.print_outlined, size: 20),
                            label: const Text('Imprimir / Generar PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
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

  Widget _infoSnippet(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _handleAddDrug() {
    if (_drugController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione o ingrese un fármaco.')),
      );
      return;
    }

    final item = PrescriptionItem(
      drugName: _drugController.text,
      dose: _doseController.text.isNotEmpty ? _doseController.text : '1 comprimido',
      frequency: _selectedFrequency,
      duration: _durationController.text.isNotEmpty ? _durationController.text : '5 días',
      instructions: _instructionsController.text.isNotEmpty
          ? _instructionsController.text
          : 'Tomar ${_doseController.text.isNotEmpty ? _doseController.text : "1 comprimido"} ${_selectedFrequency.toLowerCase()} durante ${_durationController.text.isNotEmpty ? _durationController.text : "5 días"}.',
    );

    context.read<PrescriptionProvider>().addItem(item);
    _drugController.clear();
    _doseController.clear();
    _durationController.clear();
    _instructionsController.clear();
  }
}
