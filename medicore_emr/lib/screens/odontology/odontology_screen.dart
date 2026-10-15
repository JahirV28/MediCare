import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/odontogram_finding.dart';
import '../../models/patient.dart';
import '../../providers/clinical_providers.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/common/patient_autocomplete_field.dart';

class OdontologyScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const OdontologyScreen({super.key, this.onBack});

  @override
  State<OdontologyScreen> createState() => _OdontologyScreenState();
}

class _OdontologyScreenState extends State<OdontologyScreen> {
  final _procedureController = TextEditingController(text: 'Obturación con Resina Composite');
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedAnesthesia = 'Sin anestesia';
  String _selectedStatus = 'Pendiente';

  static const List<int> _upperTeeth = [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28];
  static const List<int> _lowerTeeth = [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38];

  static const List<String> _popularProcedures = [
    'Obturación con Resina Composite',
    'Obturación con Resina Composite (MOD / Compleja)',
    'Restauración con Ionómero de Vidrio',
    'Profilaxis y Limpieza Dental con Ultrasonido',
    'Detartraje Subgingival y Raspado Radicular',
    'Endodoncia Unirradicular',
    'Endodoncia Multirradicular',
    'Exodoncia / Extracción Simple',
    'Exodoncia Quirúrgica / Cirugía Tercer Molar',
    'Corona de Porcelana / Zirconio',
    'Incrustación Dental (Inlay / Onlay)',
    'Carilla Estética Dental',
    'Sellante de Fosas y Fisuras',
    'Aplicación Tópica de Flúor Barniz',
    'Férula Oclusal / Bruxismo',
    'Implante Dental Osteointegrado',
    'Ajuste / Control de Ortodoncia',
    'Personalizado...',
  ];

  static const List<String> _conditionsList = [
    'Caries Activa / Esmalte',
    'Caries Dentinaria Profunda',
    'Pulpitis Reversible / Irreversible',
    'Tratado / Restaurado',
    'Corona / Prótesis Existente',
    'Ausente / Extracción Previa',
    'Afección Periodontal / Movilidad',
    'Fractura Coronal / Traumatismo',
    'Sano / Sin Patología',
  ];

  static const List<String> _anesthesiaOptions = [
    'Sin anestesia',
    'Lidocaína 2% con Epinefrina 1:100,000',
    'Mepivacaína 3% sin vasoconstrictor',
    'Articaína 4% con Epinefrina 1:100,000',
    'Anestesia tópica en gel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedPatient = context.read<PatientProvider>().selectedPatient;
      if (selectedPatient != null && selectedPatient.id != null) {
        context.read<OdontologyProvider>().loadOdontologyData(selectedPatient.id);
      } else {
        context.read<OdontologyProvider>().clear();
      }
    });
  }

  @override
  void dispose() {
    _procedureController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OdontologyProvider>(
      builder: (context, provider, _) {
        final teeth = provider.teethState;
        final logs = provider.logs;
        final dmft = provider.dmft;

        final activePatient = context.watch<PatientProvider>().selectedPatient;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb de navegación
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(
                    label: activePatient != null ? activePatient.fullName : 'Sin Paciente Seleccionado',
                    onTap: widget.onBack,
                  ),
                  const BreadcrumbItem(label: 'Odontograma y Salud Bucal'),
                ],
              ),
              const SizedBox(height: 20),

              // Banner del Paciente Odontológico o Selector
              if (activePatient == null)
                _buildPatientSelectorBanner(context)
              else
                _buildActivePatientBanner(context, activePatient, provider, logs),

              const SizedBox(height: 24),

              // Dos columnas: Izquierda Odontograma + Procedimientos, Derecha Formulario de Hallazgo + CPOD
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── COLUMNA IZQUIERDA: Odontograma Interactivo + Tabla ───
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Tarjeta del Odontograma
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
                              // Título y Leyenda
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Odontograma Dental Interactivo (FDI)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _legendItem(AppColors.danger, 'Caries / Pendiente'),
                                      const SizedBox(width: 14),
                                      _legendItem(AppColors.primaryBlue, 'Tratado / Restaurado'),
                                      const SizedBox(width: 14),
                                      _legendItem(Colors.grey.shade400, 'Ausente'),
                                      const SizedBox(width: 14),
                                      _legendItem(AppColors.white, 'Sano', borderColor: AppColors.border),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Contenedor de las Arcadas Dentales
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Maxilar Superior (Arcada Superior)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 16),

                                    // Piezas Superiores (18 - 28)
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 6,
                                      runSpacing: 8,
                                      children: _upperTeeth.map((tNum) {
                                        final state = teeth[tNum] ?? DentalToothState(toothNumber: tNum);
                                        final isSelected = provider.selectedTooth == tNum;
                                        return _buildToothWidget(state, isSelected, () => provider.selectTooth(tNum));
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(indent: 40, endIndent: 40),
                                    const SizedBox(height: 12),

                                    // Piezas Inferiores (48 - 38)
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 6,
                                      runSpacing: 8,
                                      children: _lowerTeeth.map((tNum) {
                                        final state = teeth[tNum] ?? DentalToothState(toothNumber: tNum);
                                        final isSelected = provider.selectedTooth == tNum;
                                        return _buildToothWidget(state, isSelected, () => provider.selectTooth(tNum));
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Mandíbula Inferior (Arcada Inferior)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tabla de Registro de Procedimientos
                        _buildProceduresTable(context, logs, provider, activePatient),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // ─── COLUMNA DERECHA: Formulario de Hallazgo + Resumen CPOD ───
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Tarjeta de Nuevo Hallazgo / Tratamiento
                        _buildFindingFormCard(context, provider, activePatient),
                        const SizedBox(height: 20),

                        // Resumen de Salud Dental: Índice CPOD (DMFT)
                        _buildDmftCard(dmft),
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

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS DE CABECERA Y SELECCIÓN DE PACIENTE
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
              Icon(Icons.person_search, color: AppColors.primaryBlue, size: 22),
              SizedBox(width: 10),
              Text(
                'Seleccione un Paciente para Odontología',
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
            'Busque y elija un paciente registrado en la base de datos para cargar su odontograma interactivo, antecedentes e historial de tratamientos.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          PatientAutocompleteField(
            hint: 'Escriba nombre o código (ej: Hernaldo, PT-...)',
            onPatientSelected: (patient) {
              if (patient != null) {
                context.read<PatientProvider>().selectPatient(patient);
                if (patient.id != null) {
                  context.read<OdontologyProvider>().loadOdontologyData(patient.id!);
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
    OdontologyProvider provider,
    List<DentalProcedureLog> logs,
  ) {
    final pName = activePatient.fullName;
    final pCode = activePatient.patientCode.isNotEmpty ? '#${activePatient.patientCode}' : '#PT-${activePatient.id}';
    final bDate = activePatient.birthDate;
    final pAge = activePatient.age;
    final pAgeStr = (bDate != null && pAge != null)
        ? 'F. Nac: ${bDate.day.toString().padLeft(2, '0')}/${bDate.month.toString().padLeft(2, '0')}/${bDate.year} ($pAge años)'
        : (pAge != null ? '$pAge años' : 'Edad no registrada');
    final pBlood = activePatient.bloodType ?? 'No reg.';
    final hasAlert = activePatient.hasAlert;

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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showChangePatientDialog(context),
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(pAgeStr, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('Grupo Sanguíneo: $pBlood', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 16,
                          color: hasAlert ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasAlert ? 'Tiene Alerta Clínica / Alergia' : 'Sin Alergias Conocidas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasAlert ? FontWeight.w600 : FontWeight.normal,
                            color: hasAlert ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showDentalHistoryModal(context, logs, provider),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Ver Historial'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showNewTreatmentModal(context, provider, activePatient),
                icon: const Icon(Icons.medical_services_outlined, size: 18),
                label: const Text('Nuevo Tratamiento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
            Icon(Icons.swap_horiz, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Cambiar Paciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione el nuevo paciente para consultar su odontograma:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              PatientAutocompleteField(
                onPatientSelected: (patient) {
                  if (patient != null) {
                    context.read<PatientProvider>().selectPatient(patient);
                    if (patient.id != null) {
                      context.read<OdontologyProvider>().loadOdontologyData(patient.id!);
                    }
                    Navigator.of(ctx).pop();
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

  // ══════════════════════════════════════════════════════════════════════════
  // TABLA DE PROCEDIMIENTOS ODONTOLÓGICOS (EDITABLE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProceduresTable(
    BuildContext context,
    List<DentalProcedureLog> logs,
    OdontologyProvider provider,
    Patient? activePatient,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Registro de Procedimientos Odontológicos',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${logs.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showDentalHistoryModal(context, logs, provider),
                  child: const Text('Ver Todo / Historial', style: TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (logs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.health_and_safety_outlined, size: 44, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    activePatient == null
                        ? 'Seleccione un paciente para ver y registrar procedimientos'
                        : 'Sin procedimientos odontológicos registrados en la base de datos',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Utilice el formulario de la derecha o "Nuevo Tratamiento" para guardar el primer hallazgo.',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppColors.background,
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('FECHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 1, child: Text('PIEZA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 4, child: Text('PROCEDIMIENTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('SUPERFICIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('ESTADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('ACCIONES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...logs.map((log) {
              final isPending = log.status == 'Pending' || log.status == 'Pendiente';
              final surfacesStr = log.surfaces.isNotEmpty ? log.surfaces.join(', ') : 'Completa';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${log.date.day.toString().padLeft(2, '0')}/${log.date.month.toString().padLeft(2, '0')}/${log.date.year}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Tooltip(
                        message: _getToothDescription(log.toothNumber),
                        child: Text(
                          '${log.toothNumber}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.procedureName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (log.notes != null && log.notes!.isNotEmpty)
                            Text(
                              log.notes!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(surfacesStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          if (log.id == null) return;
                          final newStatus = isPending ? 'Completado' : 'Pendiente';
                          await provider.updateProcedureStatus(log.id!, newStatus);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Estado actualizado a "$newStatus".'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPending ? AppColors.dangerLight : AppColors.successLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: (isPending ? AppColors.danger : AppColors.success).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPending ? Icons.pending_actions : Icons.check_circle,
                                size: 12,
                                color: isPending ? AppColors.danger : AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPending ? 'Pendiente' : 'Completado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isPending ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryBlue),
                            tooltip: 'Editar Procedimiento',
                            onPressed: () => _showEditFindingModal(context, log, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                            tooltip: 'Eliminar Registro',
                            onPressed: () => _showDeleteConfirmDialog(context, log, provider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORMULARIO LATERAL: NUEVO HALLAZGO / TRATAMIENTO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFindingFormCard(
    BuildContext context,
    OdontologyProvider provider,
    Patient? activePatient,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuevo Hallazgo / Tratamiento',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Pieza seleccionada
          const Text('Pieza Dental Seleccionada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pieza ${provider.selectedTooth} — ${_getToothDescription(provider.selectedTooth)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Superficies dentales afectadas
          const Text('Superficie(s) Afectada(s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              _surfaceCheck('Mesial (M)', 'M', provider),
              _surfaceCheck('Oclusal/Incisal (O)', 'O', provider),
              _surfaceCheck('Distal (D)', 'D', provider),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _surfaceCheck('Vestibular / Bucal (V/B)', 'B', provider),
              _surfaceCheck('Lingual / Palatino (L/P)', 'L', provider),
              _surfaceCheck('Cervical (C)', 'C', provider),
            ],
          ),
          const SizedBox(height: 14),

          // Menú desplegable de Condición
          const Text('Condición / Diagnóstico Clínico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _conditionsList.contains(provider.selectedCondition)
                ? provider.selectedCondition
                : _conditionsList.first,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _conditionsList.map((cond) => DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) {
              if (v != null) provider.setCondition(v);
            },
          ),
          const SizedBox(height: 14),

          // Nombre del Procedimiento
          const Text('Procedimiento Odontológico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          // Sugerencias rápidas de procedimientos
          DropdownButtonFormField<String>(
            hint: const Text('Elegir de catálogo...', style: TextStyle(fontSize: 12)),
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _popularProcedures.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (val) {
              if (val != null && val != 'Personalizado...') {
                _procedureController.text = val;
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _procedureController,
            decoration: InputDecoration(
              labelText: 'Procedimiento Editable',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),

          // Fila Costo y Anestesia
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Costo (MXN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0.00',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estado Inicial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Completado', child: Text('Completado', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedStatus = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Anestesia
          const Text('Anestésico Utilizado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedAnesthesia,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _anesthesiaOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedAnesthesia = v);
            },
          ),
          const SizedBox(height: 14),

          // Notas clínicas
          const Text('Notas y Observaciones Clínicas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Detalles del diagnóstico o hallazgo clínico...',
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 18),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _notesController.clear();
                    _costController.clear();
                  },
                  child: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (activePatient == null || activePatient.id == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debe seleccionar un paciente antes de registrar hallazgos.'),
                          backgroundColor: AppColors.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final success = await provider.addFinding(
                      procedureName: _procedureController.text.trim().isNotEmpty
                          ? _procedureController.text.trim()
                          : 'Evaluación y Diagnóstico',
                      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                      cost: double.tryParse(_costController.text.trim()),
                      anesthesia: _selectedAnesthesia,
                      status: _selectedStatus,
                      patientId: activePatient.id,
                    );

                    _notesController.clear();
                    _costController.clear();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Hallazgo y procedimiento guardado en Supabase con éxito.'
                              : 'Hallazgo registrado.'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  child: const Text('Guardar Hallazgo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARD DE ÍNDICE CPOD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDmftCard(DmftSummary dmft) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMEN DE SALUD DENTAL (ÍNDICE CPOD)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('Cariados (C)', '${dmft.decayed}', valueColor: AppColors.danger),
          const SizedBox(height: 8),
          _summaryRow('Perdidos / Ausentes (P)', '${dmft.missing}', valueColor: AppColors.textPrimary),
          const SizedBox(height: 8),
          _summaryRow('Obturados / Restaurados (O)', '${dmft.filled}', valueColor: AppColors.primaryBlue),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _summaryRow('Índice CPOD Total', '${dmft.dmftScore}', isBold: true),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGO MODAL: HISTORIAL CLÍNICO ODONTOLÓGICO COMPLETO
  // ══════════════════════════════════════════════════════════════════════════

  void _showDentalHistoryModal(
    BuildContext context,
    List<DentalProcedureLog> logs,
    OdontologyProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.history_edu, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Historial Clínico de Odontología', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${logs.length} Procedimiento(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 850,
                child: logs.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No se registran procedimientos odontológicos para este paciente',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Pieza')),
                            DataColumn(label: Text('Procedimiento')),
                            DataColumn(label: Text('Superficies')),
                            DataColumn(label: Text('Costo')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Acciones')),
                          ],
                          rows: logs.map((log) {
                            final isPending = log.status == 'Pending' || log.status == 'Pendiente';
                            final surfacesStr = log.surfaces.isNotEmpty ? log.surfaces.join(', ') : '-';
                            final costStr = log.cost != null && log.cost! > 0 ? '\$ ${log.cost!.toStringAsFixed(2)}' : '-';

                            return DataRow(cells: [
                              DataCell(Text('${log.date.day}/${log.date.month}/${log.date.year}')),
                              DataCell(Tooltip(
                                message: _getToothDescription(log.toothNumber),
                                child: Text('Pieza ${log.toothNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              )),
                              DataCell(SizedBox(
                                width: 220,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log.procedureName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    if (log.notes != null && log.notes!.isNotEmpty)
                                      Text(log.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              )),
                              DataCell(Text(surfacesStr)),
                              DataCell(Text(costStr)),
                              DataCell(
                                InkWell(
                                  onTap: () async {
                                    if (log.id == null) return;
                                    final newStatus = isPending ? 'Completado' : 'Pendiente';
                                    await provider.updateProcedureStatus(log.id!, newStatus);
                                    setModalState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPending ? AppColors.dangerLight : AppColors.successLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPending ? 'Pendiente' : 'Completado',
                                      style: TextStyle(
                                        color: isPending ? AppColors.danger : AppColors.success,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: AppColors.primaryBlue),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _showEditFindingModal(context, log, provider);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16, color: AppColors.danger),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _showDeleteConfirmDialog(context, log, provider);
                                      },
                                    ),
                                  ],
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
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGO MODAL: PLANIFICAR NUEVO TRATAMIENTO
  // ══════════════════════════════════════════════════════════════════════════

  void _showNewTreatmentModal(
    BuildContext context,
    OdontologyProvider provider,
    Patient? activePatient,
  ) {
    if (activePatient == null || activePatient.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un paciente primero para planificar un tratamiento.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final treatmentController = TextEditingController(text: 'Profilaxis y Limpieza Dental con Ultrasonido');
    final costController = TextEditingController(text: '850.00');
    final notesController = TextEditingController();
    int selectedTooth = provider.selectedTooth;
    String selectedCondition = 'Sano / Sin Patología';
    String selectedAnesthesia = 'Sin anestesia';
    String selectedStatus = 'Pendiente';
    final Set<String> selectedSurfaces = {};

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.medical_services, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Planificar Tratamiento Odontológico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Paciente actual
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Paciente: ${activePatient.fullName} (${activePatient.patientCode.isNotEmpty ? activePatient.patientCode : 'ID ${activePatient.id}'})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de Pieza Dental
                      const Text('Pieza Dental (FDI)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedTooth,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [..._upperTeeth, ..._lowerTeeth].map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text('Pieza $t — ${_getToothDescription(t)}', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedTooth = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Superficies
                      const Text('Superficies Dentales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['M', 'O', 'D', 'B', 'L', 'C'].map((s) {
                          final isChecked = selectedSurfaces.contains(s);
                          return FilterChip(
                            label: Text(s, style: TextStyle(fontSize: 11, fontWeight: isChecked ? FontWeight.w700 : FontWeight.normal)),
                            selected: isChecked,
                            onSelected: (sel) {
                              setDialogState(() {
                                if (sel) {
                                  selectedSurfaces.add(s);
                                } else {
                                  selectedSurfaces.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Procedimiento
                      const Text('Nombre del Procedimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        hint: const Text('Catálogo de procedimientos frecuentes...', style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _popularProcedures.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          if (val != null && val != 'Personalizado...') {
                            setDialogState(() => treatmentController.text = val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: treatmentController,
                        decoration: const InputDecoration(
                          labelText: 'Procedimiento Planificado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Condición y Estado
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Diagnóstico / Condición', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCondition,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _conditionsList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => selectedCondition = v);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estado del Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedStatus,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente / Planificado', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: 'Completado', child: Text('Completado Hoy', style: TextStyle(fontSize: 11))),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => selectedStatus = v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Costo y Anestesia
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Costo Estimado (MXN)',
                                prefixText: '\$ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedAnesthesia,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Anestésico',
                                border: OutlineInputBorder(),
                              ),
                              items: _anesthesiaOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 11)))).toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedAnesthesia = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notas
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones e Indicaciones Clínicas',
                          hintText: 'Detalles del plan de tratamiento...',
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
                    if (treatmentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor ingrese el nombre del procedimiento.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    ToothCondition cond;
                    final cLower = selectedCondition.toLowerCase();
                    if (cLower.contains('caries')) {
                      cond = ToothCondition.caries;
                    } else if (cLower.contains('trata') || cLower.contains('corona')) {
                      cond = ToothCondition.treated;
                    } else if (cLower.contains('ausen') || cLower.contains('extrac')) {
                      cond = ToothCondition.missing;
                    } else {
                      cond = ToothCondition.healthy;
                    }

                    await provider.addFinding(
                      toothNumber: selectedTooth,
                      condition: cond,
                      surfaces: selectedSurfaces.toList(),
                      procedureName: treatmentController.text.trim(),
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                      cost: double.tryParse(costController.text.trim()),
                      anesthesia: selectedAnesthesia,
                      status: selectedStatus,
                      patientId: activePatient.id,
                    );

                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tratamiento odontológico planificado y guardado en la base de datos.'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Confirmar Tratamiento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGO MODAL: EDITAR PROCEDIMIENTO EXISTENTE
  // ══════════════════════════════════════════════════════════════════════════

  void _showEditFindingModal(
    BuildContext context,
    DentalProcedureLog log,
    OdontologyProvider provider,
  ) {
    if (log.id == null) return;

    final editProcedureCtrl = TextEditingController(text: log.procedureName);
    final editCostCtrl = TextEditingController(text: log.cost != null ? log.cost!.toStringAsFixed(2) : '');
    final editNotesCtrl = TextEditingController(text: log.notes ?? '');
    int editTooth = log.toothNumber;
    String editStatus = (log.status == 'Completed' || log.status == 'Completado') ? 'Completado' : 'Pendiente';
    final Set<String> editSurfaces = Set.from(log.surfaces);

    showDialog(
      context: context,
      builder: (editCtx) {
        return StatefulBuilder(
          builder: (context, setEditState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('Editar Procedimiento Odontológico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pieza Dental
                      const Text('Pieza Dental (FDI)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: editTooth,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [..._upperTeeth, ..._lowerTeeth].map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text('Pieza $t — ${_getToothDescription(t)}', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setEditState(() => editTooth = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Superficies
                      const Text('Superficies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['M', 'O', 'D', 'B', 'L', 'C'].map((s) {
                          final isChecked = editSurfaces.contains(s);
                          return FilterChip(
                            label: Text(s, style: TextStyle(fontSize: 11, fontWeight: isChecked ? FontWeight.w700 : FontWeight.normal)),
                            selected: isChecked,
                            onSelected: (sel) {
                              setEditState(() {
                                if (sel) {
                                  editSurfaces.add(s);
                                } else {
                                  editSurfaces.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Nombre del procedimiento
                      TextField(
                        controller: editProcedureCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Procedimiento Odontológico',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Costo y Estado
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: editCostCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Costo (MXN)',
                                prefixText: '\$ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: editStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                                DropdownMenuItem(value: 'Completado', child: Text('Completado')),
                              ],
                              onChanged: (v) {
                                if (v != null) setEditState(() => editStatus = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notas
                      TextField(
                        controller: editNotesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas y Observaciones',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(editCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  onPressed: () async {
                    ToothCondition cond = ToothCondition.treated;
                    if (editStatus == 'Pendiente') {
                      cond = ToothCondition.caries;
                    }

                    await provider.updateFinding(
                      logId: log.id!,
                      toothNumber: editTooth,
                      condition: cond,
                      surfaces: editSurfaces.toList(),
                      procedureName: editProcedureCtrl.text.trim(),
                      status: editStatus,
                      cost: double.tryParse(editCostCtrl.text.trim()),
                      notes: editNotesCtrl.text.trim().isNotEmpty ? editNotesCtrl.text.trim() : null,
                    );

                    if (editCtx.mounted) Navigator.of(editCtx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Procedimiento actualizado exitosamente en la base de datos.'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
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

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGO DE CONFIRMACIÓN: ELIMINAR PROCEDIMIENTO
  // ══════════════════════════════════════════════════════════════════════════

  void _showDeleteConfirmDialog(
    BuildContext context,
    DentalProcedureLog log,
    OdontologyProvider provider,
  ) {
    if (log.id == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Eliminar Procedimiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          '¿Está seguro de que desea eliminar el procedimiento "${log.procedureName}" en la Pieza ${log.toothNumber}? Esta acción se sincronizará con la base de datos de Supabase.',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await provider.deleteFinding(log.id!);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Procedimiento eliminado de la base de datos.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS DE UI
  // ══════════════════════════════════════════════════════════════════════════

  Widget _legendItem(Color color, String label, {Color? borderColor}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildToothWidget(DentalToothState state, bool isSelected, VoidCallback onTap) {
    Color fill;
    switch (state.condition) {
      case ToothCondition.caries:
        fill = AppColors.danger;
        break;
      case ToothCondition.treated:
        fill = AppColors.primaryBlue;
        break;
      case ToothCondition.missing:
        fill = Colors.grey.shade400;
        break;
      case ToothCondition.healthy:
        fill = AppColors.white;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(
        message: 'Pieza ${state.toothNumber}: ${_getToothDescription(state.toothNumber)}',
        child: Container(
          width: 32,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isSelected ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
          ),
          child: Column(
            children: [
              Text(
                '${state.toothNumber}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceCheck(String label, String code, OdontologyProvider provider) {
    final isChecked = provider.selectedSurfaces.contains(code);
    return Expanded(
      child: InkWell(
        onTap: () => provider.toggleSurface(code),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (_) => provider.toggleSurface(code),
              activeColor: AppColors.primaryBlue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String val, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Nomenclatura odontológica FDI en Español para las 32 piezas dentales
  String _getToothDescription(int tooth) {
    switch (tooth) {
      // Cuadrante 1: Superior Derecho
      case 18: return 'Tercer Molar / Cordal Sup. Der.';
      case 17: return 'Segundo Molar Sup. Der.';
      case 16: return 'Primer Molar Sup. Der.';
      case 15: return 'Segundo Premolar Sup. Der.';
      case 14: return 'Primer Premolar Sup. Der.';
      case 13: return 'Canino Sup. Der.';
      case 12: return 'Incisivo Lateral Sup. Der.';
      case 11: return 'Incisivo Central Sup. Der.';
      // Cuadrante 2: Superior Izquierdo
      case 21: return 'Incisivo Central Sup. Izq.';
      case 22: return 'Incisivo Lateral Sup. Izq.';
      case 23: return 'Canino Sup. Izq.';
      case 24: return 'Primer Premolar Sup. Izq.';
      case 25: return 'Segundo Premolar Sup. Izq.';
      case 26: return 'Primer Molar Sup. Izq.';
      case 27: return 'Segundo Molar Sup. Izq.';
      case 28: return 'Tercer Molar / Cordal Sup. Izq.';
      // Cuadrante 3: Inferior Izquierdo
      case 31: return 'Incisivo Central Inf. Izq.';
      case 32: return 'Incisivo Lateral Inf. Izq.';
      case 33: return 'Canino Inf. Izq.';
      case 34: return 'Primer Premolar Inf. Izq.';
      case 35: return 'Segundo Premolar Inf. Izq.';
      case 36: return 'Primer Molar Inf. Izq.';
      case 37: return 'Segundo Molar Inf. Izq.';
      case 38: return 'Tercer Molar / Cordal Inf. Izq.';
      // Cuadrante 4: Inferior Derecho
      case 41: return 'Incisivo Central Inf. Der.';
      case 42: return 'Incisivo Lateral Inf. Der.';
      case 43: return 'Canino Inf. Der.';
      case 44: return 'Primer Premolar Inf. Der.';
      case 45: return 'Segundo Premolar Inf. Der.';
      case 46: return 'Primer Molar Inf. Der.';
      case 47: return 'Segundo Molar Inf. Der.';
      case 48: return 'Tercer Molar / Cordal Inf. Der.';
      default: return 'Pieza Dental $tooth';
    }
  }
}
