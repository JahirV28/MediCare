import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/cards/patient_info_card.dart';
import '../../widgets/timeline/clinical_timeline.dart';

class PatientDetailScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToConsultation;
  final VoidCallback? onNavigateToPrescription;
  final VoidCallback? onNavigateToDiagnostics;

  const PatientDetailScreen({
    super.key,
    this.onBack,
    this.onNavigateToConsultation,
    this.onNavigateToPrescription,
    this.onNavigateToDiagnostics,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().loadPatientDetail();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading || provider.selectedPatient == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        final patient = provider.selectedPatient!;
        final alerts = provider.allergyAlerts;
        final records = provider.clinicalRecords;

        return Column(
          children: [
            // Alert Banner
            if (alerts.isNotEmpty)
              AlertBanner(
                title: 'ALERTAS CRÍTICAS Y ALERGIAS',
                message: alerts
                    .map((a) =>
                        'ALERGIA A LA ${a.allergen.toUpperCase()} – ${a.reaction.toUpperCase()} (Documentado: ${_formatDate(a.documentedDate)})')
                    .join(' | '),
              ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Breadcrumb
                    Breadcrumb(
                      items: [
                        BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                        BreadcrumbItem(label: patient.fullName),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Main content: Patient card + Tabs
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Patient Info Card
                        SizedBox(
                          width: 280,
                          child: PatientInfoCard(patient: patient),
                        ),
                        const SizedBox(width: 20),

                        // Right: Tabs + Content
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tab bar
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    labelColor: AppColors.primaryBlue,
                                    unselectedLabelColor: AppColors.textSecondary,
                                    indicatorColor: AppColors.primaryBlue,
                                    indicatorWeight: 2,
                                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    tabs: const [
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timeline, size: 16),
                                            SizedBox(width: 6),
                                            Text('Historial'),
                                          ],
                                        ),
                                      ),
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.attach_file, size: 16),
                                            SizedBox(width: 6),
                                            Text('Adjuntos'),
                                          ],
                                        ),
                                      ),
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.note_outlined, size: 16),
                                            SizedBox(width: 6),
                                            Text('Notas'),
                                          ],
                                        ),
                                      ),
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.medical_information_outlined, size: 16),
                                            SizedBox(width: 6),
                                            Text('Diagnósticos'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Tab content
                                SizedBox(
                                  height: 500,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      // Historial tab
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Línea de Tiempo Clínica',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed: widget.onNavigateToPrescription,
                                                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                                      label: const Text('Nueva Receta'),
                                                      style: OutlinedButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ElevatedButton.icon(
                                                      onPressed: widget.onNavigateToConsultation,
                                                      icon: const Icon(Icons.add, size: 16),
                                                      label: const Text('Nuevo Registro (SOAP)'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppColors.primaryBlue,
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: ClinicalTimeline(records: records),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Adjuntos tab
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.folder_open, size: 48, color: AppColors.primaryBlue),
                                            const SizedBox(height: 12),
                                            const Text(
                                              '4 archivos diagnósticos disponibles',
                                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Rayos X, Paneles Sanguíneos, Interconsultas y Dermatología',
                                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: widget.onNavigateToDiagnostics,
                                              icon: const Icon(Icons.visibility, size: 16),
                                              label: const Text('Abrir Visor de Archivos Diagnósticos'),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Notas tab
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.note_outlined, size: 48, color: AppColors.primaryBlue),
                                            const SizedBox(height: 12),
                                            const Text('Notas clínicas de seguimiento', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: widget.onNavigateToConsultation,
                                              icon: const Icon(Icons.edit_note, size: 18),
                                              label: const Text('Redactar Nota SOAP'),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Diagnósticos tab
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.medical_information_outlined, size: 48, color: AppColors.primaryBlue),
                                            const SizedBox(height: 12),
                                            const Text('Diagnóstico Principal: Lumbalgia Mecánica', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                            const SizedBox(height: 4),
                                            const Text('CIE-10: M54.5 - Lumbago no especificado', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: widget.onNavigateToPrescription,
                                              icon: const Icon(Icons.medication_outlined, size: 18),
                                              label: const Text('Emitir Receta Farmacológica'),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
