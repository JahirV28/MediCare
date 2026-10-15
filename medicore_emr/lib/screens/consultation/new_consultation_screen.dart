import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/clinical_providers.dart';
import '../../providers/patient_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/breadcrumb.dart';

class NewConsultationScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  const NewConsultationScreen({super.key, this.onBack, this.onSaved});

  @override
  State<NewConsultationScreen> createState() => _NewConsultationScreenState();
}

class _NewConsultationScreenState extends State<NewConsultationScreen> {
  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _icd10Controller = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();

  final _bpSysController = TextEditingController(text: '120');
  final _bpDiaController = TextEditingController(text: '80');
  final _pulseController = TextEditingController(text: '72');
  final _tempController = TextEditingController(text: '36.5');
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '175');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patient = context.read<PatientProvider>().selectedPatient;
      final provider = context.read<ConsultationProvider>();
      await provider.loadConsultation(
        patient?.fullName ?? 'Paciente General',
        patient?.patientCode ?? 'PT-001',
        patientId: patient?.id,
      );
      if (!mounted) return;
      final c = provider.currentConsultation;
      if (c != null) {
        _subjectiveController.text = c.subjective;
        _objectiveController.text = c.objective;
        _icd10Controller.text = c.icd10Code;
        _assessmentController.text = c.assessment;
        _planController.text = c.plan;
        _bpSysController.text = c.vitalSigns.bpSystolic.toString();
        _bpDiaController.text = c.vitalSigns.bpDiastolic.toString();
        _pulseController.text = c.vitalSigns.pulse.toString();
        _tempController.text = c.vitalSigns.temperature.toString();
        _weightController.text = c.vitalSigns.weightKg.toString();
        _heightController.text = c.vitalSigns.heightCm.toString();
      }
    });
  }

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _icd10Controller.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _bpSysController.dispose();
    _bpDiaController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  double _calculateBmi() {
    final w = double.tryParse(_weightController.text) ?? 70.0;
    final h = double.tryParse(_heightController.text) ?? 175.0;
    if (h <= 0) return 0.0;
    final hM = h / 100.0;
    return double.parse((w / (hM * hM)).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConsultationProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(
                    label: context.watch<PatientProvider>().selectedPatient?.fullName ?? 'Expediente',
                    onTap: widget.onBack,
                  ),
                  const BreadcrumbItem(label: 'Nueva Consulta'),
                ],
              ),
              const SizedBox(height: 20),

              // Title and Actions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nueva Consulta (SOAP)',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<PatientProvider>(
                        builder: (context, patProvider, _) {
                          final p = patProvider.selectedPatient;
                          final name = p?.fullName ?? 'Paciente General';
                          final code = p?.patientCode ?? '-';
                          final dateStr = _formatDate(DateTime.now());
                          return Text(
                            'Fecha: $dateStr | Paciente: $name (ID: $code)',
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
                      OutlinedButton(
                        onPressed: () => _handleSave(isFinalized: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text('Guardar Borrador'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _handleSave(isFinalized: true),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Firmar y Finalizar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Two columns: Left Vitals + Right SOAP Notes
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── LEFT: Vital Signs Card ───
                  SizedBox(
                    width: 280,
                    child: Container(
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
                            children: [
                              Icon(Icons.favorite_border, size: 20, color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              const Text(
                                'Signos Vitales',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Blood Pressure
                          const Text(
                            'Presión Arterial (PA)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumericField(_bpSysController, '120'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('/', style: TextStyle(fontSize: 16, color: AppColors.textHint)),
                              ),
                              Expanded(
                                child: _buildNumericField(_bpDiaController, '80'),
                              ),
                              const SizedBox(width: 8),
                              const Text('mmHg', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Pulse
                          const Text(
                            'Pulso',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _buildNumericField(_pulseController, '72')),
                              const SizedBox(width: 8),
                              const Text('bpm', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Temperature
                          const Text(
                            'Temperatura',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _buildNumericField(_tempController, '36.5')),
                              const SizedBox(width: 8),
                              const Text('°C', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Weight & Height
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Peso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(child: _buildNumericField(_weightController, '70', onChanged: (_) => setState(() {}))),
                                        const SizedBox(width: 4),
                                        const Text('kg', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Altura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(child: _buildNumericField(_heightController, '175', onChanged: (_) => setState(() {}))),
                                        const SizedBox(width: 4),
                                        const Text('cm', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // BMI Result Container
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'BMI (Auto)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_calculateBmi()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // ─── RIGHT: Clinical Notes (SOAP) ───
                  Expanded(
                    child: Column(
                      children: [
                        // Card 1: S + O Notes
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
                                'Notas Clínicas',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),

                              // S - Subjetivo
                              _buildSoapHeader('S', 'Subjetivo (Síntomas y Motivo de Consulta)'),
                              const SizedBox(height: 8),
                              _buildTextarea(_subjectiveController, 'El paciente reporta...'),
                              const SizedBox(height: 20),
                              const Divider(height: 1, indent: 4, endIndent: 4),
                              const SizedBox(height: 20),

                              // O - Objetivo
                              _buildSoapHeader('O', 'Objetivo (Hallazgos del Examen Físico)'),
                              const SizedBox(height: 8),
                              _buildTextarea(_objectiveController, 'El examen físico revela...'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Card 2: A + P Notes
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
                              // A - Análisis
                              _buildSoapHeader('A', 'Análisis (Evaluación y Diagnóstico)'),
                              const SizedBox(height: 12),
                              // ICD-10 Search
                              TextField(
                                controller: _icd10Controller,
                                decoration: InputDecoration(
                                  hintText: 'Buscar códigos CIE-10 / ICD-10...',
                                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildTextarea(_assessmentController, 'Evaluación clínica basada en los hallazgos...'),
                              const SizedBox(height: 20),
                              const Divider(height: 1, indent: 4, endIndent: 4),
                              const SizedBox(height: 20),

                              // P - Plan
                              _buildSoapHeader('P', 'Plan (Tratamiento, Medicamentos, Seguimiento)'),
                              const SizedBox(height: 8),
                              _buildTextarea(_planController, 'Prescripciones, procedimientos y próximos pasos...'),
                            ],
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

  Widget _buildSoapHeader(String badgeLetter, String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badgeLetter,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNumericField(TextEditingController controller, String hint, {Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildTextarea(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(fontSize: 13, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  void _handleSave({required bool isFinalized}) async {
    final patient = context.read<PatientProvider>().selectedPatient;
    final provider = context.read<ConsultationProvider>();
    provider.updateVitals(
      bpSystolic: int.tryParse(_bpSysController.text) ?? 120,
      bpDiastolic: int.tryParse(_bpDiaController.text) ?? 80,
      pulse: int.tryParse(_pulseController.text) ?? 72,
      temperature: double.tryParse(_tempController.text) ?? 36.5,
      weightKg: double.tryParse(_weightController.text) ?? 70.0,
      heightCm: double.tryParse(_heightController.text) ?? 175.0,
    );

    final success = await provider.saveConsultation(
      subjective: _subjectiveController.text,
      objective: _objectiveController.text,
      icd10Code: _icd10Controller.text,
      assessment: _assessmentController.text,
      plan: _planController.text,
      isFinalized: isFinalized,
      patientId: patient?.id,
      patientName: patient?.fullName,
      patientCode: patient?.patientCode,
    );

    if (success && mounted) {
      if (isFinalized) {
        await context.read<DashboardProvider>().recordIncome(
          100.0,
          patientId: patient?.id,
          concept: 'Consulta SOAP: ${patient?.fullName ?? "Paciente"}',
        );
      }
      if (!mounted) return;
      // Actualizar detalle de paciente en vivo para que su línea de tiempo muestre la consulta
      await context.read<PatientProvider>().loadPatientDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFinalized
                ? 'Consulta firmada y finalizada con éxito. Registrada en el expediente.'
                : 'Borrador guardado exitosamente.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSaved?.call();
      }
    }
  }
}
