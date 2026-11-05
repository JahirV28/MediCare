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
    'Sano / Sin Patología',
    'Caries Activa / Esmalte',
    'Caries Dentinaria Profunda',
    'Tratado / Restaurado',
    'Corona / Prótesis Existente',
    'Endodoncia / Tratamiento de Conducto',
    'Ausente / Extracción Previa',
    'Afección Periodontal / Movilidad',
    'Fractura Coronal / Traumatismo',
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patientProv = context.read<PatientProvider>();
      final odontoProv = context.read<OdontologyProvider>();

      if (patientProv.selectedPatient != null && patientProv.selectedPatient!.id != null) {
        await odontoProv.loadOdontologyData(patientProv.selectedPatient!.id);
      } else {
        if (patientProv.patients.isEmpty) {
          await patientProv.loadPatients();
        }
        if (patientProv.patients.isNotEmpty) {
          final defaultPatient = patientProv.patients.firstWhere(
            (p) => p.id == 7,
            orElse: () => patientProv.patients.first,
          );
          patientProv.selectPatient(defaultPatient);
          if (defaultPatient.id != null) {
            await odontoProv.loadOdontologyData(defaultPatient.id);
          }
        } else {
          odontoProv.clear();
        }
      }
    });
  }

  void _onToothSelected(int toothNum, OdontologyProvider provider) {
    provider.selectTooth(toothNum);
    final toothState = provider.teethState[toothNum];
    if (toothState != null && toothState.activeProcedure != null && toothState.activeProcedure!.isNotEmpty) {
      _procedureController.text = toothState.activeProcedure!;
    } else {
      _procedureController.text = 'Obturación con Resina Composite';
    }
    if (toothState?.condition == ToothCondition.treated) {
      setState(() => _selectedStatus = 'Completado');
    } else {
      setState(() => _selectedStatus = 'Pendiente');
    }
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

                              // Contenedor de las Arcadas Dentales (Organizado por Cuadrantes Anatómicos FDI)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Column(
                                    children: [
                                      // Cabecera Arcada Superior
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.expand_less, size: 16, color: AppColors.textSecondary),
                                          SizedBox(width: 4),
                                          Text(
                                            'Maxilar Superior (Arcada Superior)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.expand_less, size: 16, color: AppColors.textSecondary),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Fila Superior: Cuadrante 1 (18-11) | Línea Media | Cuadrante 2 (21-28)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Cuadrante 1
                                          Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('C1: Sup. Derecho', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [18, 17, 16, 15, 14, 13, 12, 11].map((tNum) {
                                                   final isSel = provider.selectedTooth == tNum;
                                                   final state = isSel
                                                       ? DentalToothState(
                                                           toothNumber: tNum,
                                                           condition: provider.currentResolvedCondition,
                                                           affectedSurfaces: provider.selectedSurfaces.toList(),
                                                           activeProcedure: _procedureController.text,
                                                         )
                                                       : (teeth[tNum] ?? DentalToothState(toothNumber: tNum));
                                                   return _buildToothWidget(
                                                     state,
                                                     isSel,
                                                     () => _onToothSelected(tNum, provider),
                                                     onSurfaceTapped: (surf) {
                                                       if (!isSel) _onToothSelected(tNum, provider);
                                                       provider.toggleSurface(surf);
                                                     },
                                                   );
                                                 }).toList(),
                                              ),
                                            ],
                                          ),

                                          // Línea Media Separadora Superior
                                          Container(
                                            height: 64,
                                            width: 2,
                                            margin: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(1),
                                            ),
                                          ),

                                          // Cuadrante 2
                                          Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('C2: Sup. Izquierdo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [21, 22, 23, 24, 25, 26, 27, 28].map((tNum) {
                                                   final isSel = provider.selectedTooth == tNum;
                                                   final state = isSel
                                                       ? DentalToothState(
                                                           toothNumber: tNum,
                                                           condition: provider.currentResolvedCondition,
                                                           affectedSurfaces: provider.selectedSurfaces.toList(),
                                                           activeProcedure: _procedureController.text,
                                                         )
                                                       : (teeth[tNum] ?? DentalToothState(toothNumber: tNum));
                                                   return _buildToothWidget(
                                                     state,
                                                     isSel,
                                                     () => _onToothSelected(tNum, provider),
                                                     onSurfaceTapped: (surf) {
                                                       if (!isSel) _onToothSelected(tNum, provider);
                                                       provider.toggleSurface(surf);
                                                     },
                                                   );
                                                 }).toList(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),
                                      const Divider(height: 1, indent: 20, endIndent: 20),
                                      const SizedBox(height: 14),

                                      // Fila Inferior: Cuadrante 4 (48-41) | Línea Media | Cuadrante 3 (31-38)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Cuadrante 4
                                          Column(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [48, 47, 46, 45, 44, 43, 42, 41].map((tNum) {
                                                   final isSel = provider.selectedTooth == tNum;
                                                   final state = isSel
                                                       ? DentalToothState(
                                                           toothNumber: tNum,
                                                           condition: provider.currentResolvedCondition,
                                                           affectedSurfaces: provider.selectedSurfaces.toList(),
                                                           activeProcedure: _procedureController.text,
                                                         )
                                                       : (teeth[tNum] ?? DentalToothState(toothNumber: tNum));
                                                   return _buildToothWidget(
                                                     state,
                                                     isSel,
                                                     () => _onToothSelected(tNum, provider),
                                                     onSurfaceTapped: (surf) {
                                                       if (!isSel) _onToothSelected(tNum, provider);
                                                       provider.toggleSurface(surf);
                                                     },
                                                   );
                                                 }).toList(),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('C4: Inf. Derecho', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                              ),
                                            ],
                                          ),

                                          // Línea Media Separadora Inferior
                                          Container(
                                            height: 64,
                                            width: 2,
                                            margin: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(1),
                                            ),
                                          ),

                                          // Cuadrante 3
                                          Column(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [31, 32, 33, 34, 35, 36, 37, 38].map((tNum) {
                                                   final isSel = provider.selectedTooth == tNum;
                                                   final state = isSel
                                                       ? DentalToothState(
                                                           toothNumber: tNum,
                                                           condition: provider.currentResolvedCondition,
                                                           affectedSurfaces: provider.selectedSurfaces.toList(),
                                                           activeProcedure: _procedureController.text,
                                                         )
                                                       : (teeth[tNum] ?? DentalToothState(toothNumber: tNum));
                                                   return _buildToothWidget(
                                                     state,
                                                     isSel,
                                                     () => _onToothSelected(tNum, provider),
                                                     onSurfaceTapped: (surf) {
                                                       if (!isSel) _onToothSelected(tNum, provider);
                                                       provider.toggleSurface(surf);
                                                     },
                                                   );
                                                 }).toList(),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('C3: Inf. Izquierdo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
                                          SizedBox(width: 4),
                                          Text(
                                            'Mandíbula Inferior (Arcada Inferior)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ],
                                  ),
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
    final tNum = provider.selectedTooth;
    final isUpper = _upperTeeth.contains(tNum);
    final isRightSideOfPatient = (tNum >= 11 && tNum <= 18) || (tNum >= 41 && tNum <= 48);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nuevo Hallazgo / Tratamiento',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Pieza FDI $tNum',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tarjeta informativa de la pieza seleccionada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_information_outlined, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pieza $tNum — ${_getToothDescription(tNum)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        isUpper ? 'Arcada Superior' : 'Mandíbula Inferior',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── VISOR INTERACTIVO DE CORONA FDI (Toque directo en caras) ───
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, size: 14, color: AppColors.primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      'Haga clic directamente en las caras del diente',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LargeToothCrownInspector(
                  state: DentalToothState(
                    toothNumber: tNum,
                    condition: provider.currentResolvedCondition,
                    affectedSurfaces: provider.selectedSurfaces.toList(),
                    activeProcedure: _procedureController.text,
                  ),
                  isUpper: isUpper,
                  onSurfaceTapped: (surf) => provider.toggleSurface(surf),
                ),
                const SizedBox(height: 10),
                // Botones rápidos de selección
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 14),
                      label: const Text('Marcar 5 Caras', style: TextStyle(fontSize: 11)),
                      onPressed: () => provider.selectAllSurfaces(),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 14),
                      label: const Text('Desmarcar Caras', style: TextStyle(fontSize: 11)),
                      onPressed: () => provider.clearSelectedSurfaces(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Chips de superficies anatómicas
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _surfaceChip('Oclusal (O)', 'O', provider),
                    _surfaceChip(isUpper ? 'Vestibular (V)' : 'Bucal (B)', 'B', provider),
                    _surfaceChip(isUpper ? 'Palatino (P)' : 'Lingual (L)', 'L', provider),
                    _surfaceChip(isRightSideOfPatient ? 'Distal (D)' : 'Mesial (M)', 'M', provider),
                    _surfaceChip(isRightSideOfPatient ? 'Mesial (M)' : 'Distal (D)', 'D', provider),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── SELECTOR DIRECTO DE CONDICIÓN CLÍNICA (4 Tarjetas Rápidas) ───
          const Text('Diagnóstico / Condición Clínica', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildConditionCard(
                label: 'Caries Activa',
                subtitle: 'Rojo',
                color: const Color(0xFFEF4444),
                icon: Icons.coronavirus_outlined,
                isSelected: provider.currentResolvedCondition == ToothCondition.caries,
                onTap: () => provider.setCondition('Caries Activa / Esmalte'),
              ),
              const SizedBox(width: 8),
              _buildConditionCard(
                label: 'Tratado / Obturado',
                subtitle: 'Azul',
                color: const Color(0xFF2563EB),
                icon: Icons.healing,
                isSelected: provider.currentResolvedCondition == ToothCondition.treated,
                onTap: () => provider.setCondition('Tratado / Restaurado'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildConditionCard(
                label: 'Ausente / Extraído',
                subtitle: 'Cruz "X"',
                color: const Color(0xFF64748B),
                icon: Icons.cancel_outlined,
                isSelected: provider.currentResolvedCondition == ToothCondition.missing,
                onTap: () => provider.setCondition('Ausente / Extracción Previa'),
              ),
              const SizedBox(width: 8),
              _buildConditionCard(
                label: 'Sano / Sin Patología',
                subtitle: 'Limpio',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_outline,
                isSelected: provider.currentResolvedCondition == ToothCondition.healthy && provider.selectedSurfaces.isEmpty,
                onTap: () => provider.clearSelectedSurfaces(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Procedimiento Odontológico
          const Text('Procedimiento Odontológico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
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
                final valLower = val.toLowerCase();
                if (valLower.contains('obtur') ||
                    valLower.contains('resina') ||
                    valLower.contains('amalgama') ||
                    valLower.contains('corona') ||
                    valLower.contains('incrusta') ||
                    valLower.contains('endodoncia') ||
                    valLower.contains('reconstruc')) {
                  provider.setCondition('Tratado / Restaurado');
                }
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

          // Fila Costo y Estado
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
                    provider.clearSelectedSurfaces();
                  },
                  child: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar Hallazgo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
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

                    final cond = provider.currentResolvedCondition;
                    final procName = _procedureController.text.trim().isNotEmpty
                        ? _procedureController.text.trim()
                        : 'Evaluación y Diagnóstico';

                    final success = await provider.addFinding(
                      toothNumber: provider.selectedTooth,
                      condition: cond,
                      procedureName: procName,
                      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                      cost: double.tryParse(_costController.text.trim()),
                      anesthesia: _selectedAnesthesia,
                      status: _selectedStatus,
                      patientId: activePatient.id,
                    );

                    _notesController.clear();
                    _costController.clear();

                    if (context.mounted) {
                      final condLabel = cond == ToothCondition.caries
                          ? 'Caries Activa'
                          : (cond == ToothCondition.treated
                              ? 'Tratado'
                              : (cond == ToothCondition.missing ? 'Ausente' : 'Sano'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Pieza ${provider.selectedTooth} guardada exitosamente ($condLabel).'
                              : 'Error al sincronizar con el servidor.'),
                          backgroundColor: success ? const Color(0xFF10B981) : AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                        children: ['M', 'O', 'D', 'B', 'L'].map((s) {
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
                    } else if (cLower.contains('trata') ||
                        cLower.contains('corona') ||
                        cLower.contains('obtur') ||
                        cLower.contains('conducto') ||
                        cLower.contains('endodoncia') ||
                        cLower.contains('incrusta')) {
                      cond = ToothCondition.treated;
                    } else if (cLower.contains('ausen') || cLower.contains('extrac') || cLower.contains('perdid')) {
                      cond = ToothCondition.missing;
                    } else {
                      cond = ToothCondition.healthy;
                    }

                    // Si no se marcó ninguna superficie y no es pieza ausente, se normaliza a sana
                    if (provider.selectedSurfaces.isEmpty && cond != ToothCondition.missing) {
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
    String editCondition = 'Tratado / Restaurado';
    if (log.condition != null) {
      final logC = log.condition!.toLowerCase();
      if (logC.contains('caries')) {
        editCondition = 'Caries Activa / Esmalte';
      } else if (logC.contains('ausen') || logC.contains('miss') || logC.contains('extrac')) {
        editCondition = 'Ausente / Extracción Previa';
      } else if (logC.contains('sano') || logC.contains('healthy')) {
        editCondition = 'Sano / Sin Patología';
      }
    }

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

                      // Diagnóstico / Condición Clínica
                      const Text('Diagnóstico / Condición', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: editCondition,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _conditionsList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (v) {
                          if (v != null) setEditState(() => editCondition = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Superficies
                      const Text('Superficies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['M', 'O', 'D', 'B', 'L'].map((s) {
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
                    ToothCondition cond;
                    final cLower = editCondition.toLowerCase();
                    if (cLower.contains('caries')) {
                      cond = ToothCondition.caries;
                    } else if (cLower.contains('trata') ||
                        cLower.contains('obtur') ||
                        cLower.contains('corona') ||
                        cLower.contains('endodoncia') ||
                        cLower.contains('conducto') ||
                        cLower.contains('incrusta')) {
                      cond = ToothCondition.treated;
                    } else if (cLower.contains('ausen') || cLower.contains('extrac') || cLower.contains('perdid')) {
                      cond = ToothCondition.missing;
                    } else {
                      cond = ToothCondition.healthy;
                    }

                    // Si no se marcó ninguna superficie y no es pieza ausente, se normaliza a sana
                    if (provider.selectedSurfaces.isEmpty && cond != ToothCondition.missing) {
                      cond = ToothCondition.healthy;
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

  Widget _buildToothWidget(
    DentalToothState state,
    bool isSelected,
    VoidCallback onTap, {
    Function(String surface)? onSurfaceTapped,
  }) {
    final tNum = state.toothNumber;
    final isUpper = _upperTeeth.contains(tNum);

    String condLabel = 'Sano';
    if (state.condition == ToothCondition.caries) condLabel = 'Caries';
    if (state.condition == ToothCondition.treated) condLabel = 'Tratado';
    if (state.condition == ToothCondition.missing) condLabel = 'Ausente';

    final surfStr = state.affectedSurfaces.isNotEmpty ? ' (${state.affectedSurfaces.join(",")})' : '';
    final procStr = state.activeProcedure != null && state.activeProcedure!.isNotEmpty ? '\n${state.activeProcedure}' : '';

    return Tooltip(
      message: 'Pieza $tNum: ${_getToothDescription(tNum)}\nEstado: $condLabel$surfStr$procStr\n(Toque para seleccionar o marcar cara)',
      child: Container(
        width: 36,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: AppColors.primaryBlue, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$tNum',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  onTap();
                  if (onSurfaceTapped != null) {
                    final pos = details.localPosition;
                    const w = 28.0;
                    const h = 28.0;
                    final isRightSideOfPatient = (tNum >= 11 && tNum <= 18) || (tNum >= 41 && tNum <= 48);
                    final topSurface = isUpper ? 'B' : 'L';
                    final bottomSurface = isUpper ? 'L' : 'B';
                    final leftSurface = isRightSideOfPatient ? 'D' : 'M';
                    final rightSurface = isRightSideOfPatient ? 'M' : 'D';

                    String surf = 'O';
                    if (pos.dx >= w * 0.28 && pos.dx <= w * 0.72 && pos.dy >= h * 0.28 && pos.dy <= h * 0.72) {
                      surf = 'O';
                    } else if (pos.dy < h * 0.28) {
                      surf = topSurface;
                    } else if (pos.dy > h * 0.72) {
                      surf = bottomSurface;
                    } else if (pos.dx < w * 0.28) {
                      surf = leftSurface;
                    } else {
                      surf = rightSurface;
                    }
                    onSurfaceTapped(surf);
                  }
                },
                child: CustomPaint(
                  size: const Size(28, 28),
                  painter: ToothPainter(state: state, isUpper: isUpper),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (state.activeProcedure != null &&
                          state.activeProcedure!.isNotEmpty &&
                          (state.affectedSurfaces.isNotEmpty || state.condition == ToothCondition.missing))
                      ? (state.condition == ToothCondition.caries ? AppColors.danger : AppColors.primaryBlue)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionCard({
    required String label,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? color.withValues(alpha: 0.8) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceChip(String label, String code, OdontologyProvider provider) {
    final isChecked = provider.selectedSurfaces.contains(code);
    final condColor = provider.currentResolvedCondition == ToothCondition.treated
        ? AppColors.primaryBlue
        : (provider.currentResolvedCondition == ToothCondition.caries ? AppColors.danger : AppColors.primaryBlue);
    return FilterChip(
      label: Text(label, style: TextStyle(
        fontSize: 11,
        fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
        color: isChecked ? Colors.white : AppColors.textPrimary,
      )),
      selected: isChecked,
      selectedColor: condColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: isChecked ? condColor : AppColors.border),
      ),
      onSelected: (_) => provider.toggleSurface(code),
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

/// Widget para inspeccionar y marcar interactivamente la corona de la pieza seleccionada (FDI)
class LargeToothCrownInspector extends StatelessWidget {
  final DentalToothState state;
  final bool isUpper;
  final Function(String surface) onSurfaceTapped;

  const LargeToothCrownInspector({
    super.key,
    required this.state,
    required this.isUpper,
    required this.onSurfaceTapped,
  });

  @override
  Widget build(BuildContext context) {
    final tNum = state.toothNumber;
    final isRightSideOfPatient = (tNum >= 11 && tNum <= 18) || (tNum >= 41 && tNum <= 48);
    final topSurface = isUpper ? 'B' : 'L';
    final bottomSurface = isUpper ? 'L' : 'B';
    final leftSurface = isRightSideOfPatient ? 'D' : 'M';
    final rightSurface = isRightSideOfPatient ? 'M' : 'D';

    const double crownSize = 100.0;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final pos = details.localPosition;
          const w = crownSize;
          const h = crownSize;
          String surf = 'O';
          if (pos.dx >= w * 0.28 && pos.dx <= w * 0.72 && pos.dy >= h * 0.28 && pos.dy <= h * 0.72) {
            surf = 'O';
          } else if (pos.dy < h * 0.28) {
            surf = topSurface;
          } else if (pos.dy > h * 0.72) {
            surf = bottomSurface;
          } else if (pos.dx < w * 0.28) {
            surf = leftSurface;
          } else {
            surf = rightSurface;
          }
          onSurfaceTapped(surf);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: CustomPaint(
            size: const Size(crownSize, crownSize),
            painter: ToothPainter(
              state: state,
              isUpper: isUpper,
              showLabels: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter para renderizar las 5 superficies anatómicas de cada pieza dental FDI
class ToothPainter extends CustomPainter {
  final DentalToothState state;
  final bool isUpper;
  final bool showLabels;

  ToothPainter({
    required this.state,
    required this.isUpper,
    this.showLabels = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final borderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(3),
    );

    // Si la pieza está ausente / extraída, dibuja una "X" roja/oscura sobre fondo suave
    if (state.condition == ToothCondition.missing) {
      final bgPaint = Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderPaint);

      final crossPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(3, 3), Offset(w - 3, h - 3), crossPaint);
      canvas.drawLine(Offset(w - 3, 3), Offset(3, h - 3), crossPaint);
      return;
    }

    final tNum = state.toothNumber;
    final isRightSideOfPatient = (tNum >= 11 && tNum <= 18) || (tNum >= 41 && tNum <= 48);

    // Mapeo anatómico de superficies según la posición en la arcada dental
    final topSurface = isUpper ? 'B' : 'L';
    final bottomSurface = isUpper ? 'L' : 'B';
    final leftSurface = isRightSideOfPatient ? 'D' : 'M';
    final rightSurface = isRightSideOfPatient ? 'M' : 'D';

    Color getSurfaceColor(String surfaceCode) {
      if (state.condition == ToothCondition.healthy || state.affectedSurfaces.isEmpty) {
        return Colors.white;
      }
      final isAffected = state.affectedSurfaces.any((s) {
        final sUpper = s.toUpperCase();
        if (surfaceCode == 'B') return sUpper == 'B' || sUpper == 'V';
        if (surfaceCode == 'L') return sUpper == 'L' || sUpper == 'P';
        return sUpper == surfaceCode;
      });

      if (!isAffected) return Colors.white;

      if (state.condition == ToothCondition.caries) {
        return const Color(0xFFEF4444); // Rojo para Caries activa
      } else if (state.condition == ToothCondition.treated) {
        return const Color(0xFF2563EB); // Azul para Tratado / Restaurado
      }
      return Colors.white;
    }

    final centerColor = getSurfaceColor('O');
    final topColor = getSurfaceColor(topSurface);
    final bottomColor = getSurfaceColor(bottomSurface);
    final leftColor = getSurfaceColor(leftSurface);
    final rightColor = getSurfaceColor(rightSurface);

    final cLeft = w * 0.28;
    final cTop = h * 0.28;
    final cRight = w * 0.72;
    final cBottom = h * 0.72;

    // Superficie Superior (Vestibular o Lingual)
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(cRight, cTop)
      ..lineTo(cLeft, cTop)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topColor..style = PaintingStyle.fill);
    canvas.drawPath(topPath, borderPaint);

    // Superficie Inferior (Lingual o Vestibular)
    final bottomPath = Path()
      ..moveTo(cLeft, cBottom)
      ..lineTo(cRight, cBottom)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bottomPath, Paint()..color = bottomColor..style = PaintingStyle.fill);
    canvas.drawPath(bottomPath, borderPaint);

    // Superficie Izquierda (Distal o Mesial)
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(cLeft, cTop)
      ..lineTo(cLeft, cBottom)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = leftColor..style = PaintingStyle.fill);
    canvas.drawPath(leftPath, borderPaint);

    // Superficie Derecha (Mesial o Distal)
    final rightPath = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(cRight, cBottom)
      ..lineTo(cRight, cTop)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = rightColor..style = PaintingStyle.fill);
    canvas.drawPath(rightPath, borderPaint);

    // Superficie Central (Oclusal / Incisal)
    final centerRect = Rect.fromLTRB(cLeft, cTop, cRight, cBottom);
    canvas.drawRect(centerRect, Paint()..color = centerColor..style = PaintingStyle.fill);
    canvas.drawRect(centerRect, borderPaint);

    // Borde exterior
    canvas.drawRRect(rrect, borderPaint);

    // Etiquetas anatómicas para visor ampliado
    if (showLabels) {
      final textPaint = TextPainter(textDirection: TextDirection.ltr);

      void drawLabel(String text, double cx, double cy, Color surfaceBg) {
        final isDark = surfaceBg == const Color(0xFFEF4444) || surfaceBg == const Color(0xFF2563EB);
        textPaint.text = TextSpan(
          text: text,
          style: TextStyle(
            fontSize: w > 70 ? 13 : 9,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF475569),
          ),
        );
        textPaint.layout();
        textPaint.paint(canvas, Offset(cx - textPaint.width / 2, cy - textPaint.height / 2));
      }

      drawLabel('O', w / 2, h / 2, centerColor);
      drawLabel(isUpper ? 'V' : 'L', w / 2, h * 0.14, topColor);
      drawLabel(isUpper ? 'L' : 'V', w / 2, h * 0.86, bottomColor);
      drawLabel(isRightSideOfPatient ? 'D' : 'M', w * 0.14, h / 2, leftColor);
      drawLabel(isRightSideOfPatient ? 'M' : 'D', w * 0.86, h / 2, rightColor);
    }
  }

  @override
  bool shouldRepaint(covariant ToothPainter oldDelegate) {
    return true;
  }
}
