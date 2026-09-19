import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/odontogram_finding.dart';
import '../../providers/clinical_providers.dart';
import '../../widgets/common/breadcrumb.dart';

class OdontologyScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const OdontologyScreen({super.key, this.onBack});

  @override
  State<OdontologyScreen> createState() => _OdontologyScreenState();
}

class _OdontologyScreenState extends State<OdontologyScreen> {
  final _procedureController = TextEditingController(text: 'Restauración con Resina / Composite (MOD)');
  final _notesController = TextEditingController();

  static const List<int> _upperTeeth = [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28];
  static const List<int> _lowerTeeth = [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OdontologyProvider>().loadOdontologyData(88241);
    });
  }

  @override
  void dispose() {
    _procedureController.dispose();
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb de navegación
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Pacientes', onTap: widget.onBack),
                  BreadcrumbItem(label: 'Sarah Jenkins', onTap: widget.onBack),
                  const BreadcrumbItem(label: 'Odontograma y Salud Bucal'),
                ],
              ),
              const SizedBox(height: 20),

              // Banner del Paciente Odontológico
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Sarah Jenkins',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '#EXP-88241',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Text('F. Nac: 12/04/1985 (38 años)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            SizedBox(width: 16),
                            Text('Grupo Sanguíneo: A+', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            SizedBox(width: 16),
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                                SizedBox(width: 4),
                                Text('Sin Alergias Conocidas', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showDentalHistoryModal(context, logs),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Ver Historial'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showNewTreatmentModal(context, provider),
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
              ),
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
                                    'Odontograma Dental Interactivo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _legendItem(AppColors.danger, 'Caries / Pendiente'),
                                      const SizedBox(width: 16),
                                      _legendItem(AppColors.primaryBlue, 'Tratado / Restaurado'),
                                      const SizedBox(width: 16),
                                      _legendItem(AppColors.border, 'Sano', borderColor: AppColors.textHint),
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
                        Container(
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
                                    const Text(
                                      'Registro de Procedimientos Odontológicos',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    TextButton(
                                      onPressed: () => _showDentalHistoryModal(context, logs),
                                      child: const Text('Ver Todo', style: TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                color: AppColors.background,
                                child: const Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('FECHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 1, child: Text('PIEZA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 4, child: Text('PROCEDIMIENTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('ESTADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('PROFESIONAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                                  ],
                                ),
                              ),
                              ...logs.map((log) => Container(
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
                                          child: Text('${log.toothNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(log.procedureName, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (log.status == 'Pending' || log.status == 'Pendiente') ? AppColors.dangerLight : AppColors.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              (log.status == 'Pending' || log.status == 'Pendiente') ? 'Pendiente' : 'Completado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: (log.status == 'Pending' || log.status == 'Pendiente') ? AppColors.danger : AppColors.primaryBlue,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(log.providerName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
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
                              const Text(
                                'Nuevo Hallazgo / Tratamiento',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 16),

                              // Diente seleccionado
                              const Text('Pieza Dental Seleccionada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'Pieza ${provider.selectedTooth} — ${_getToothDescription(provider.selectedTooth)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Superficies Dentales en Español
                              const Text('Superficie(s) Afectada(s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _surfaceCheck('Mesial (M)', 'M', provider),
                                  _surfaceCheck('Oclusal (O)', 'O', provider),
                                  _surfaceCheck('Distal (D)', 'D', provider),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _surfaceCheck('Vestibular / Bucal (V/B)', 'B', provider),
                                  _surfaceCheck('Lingual / Palatino (L/P)', 'L', provider),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Menú desplegable de Condición
                              const Text('Condición / Diagnóstico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: provider.selectedCondition,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Caries', child: Text('Caries Activa')),
                                  DropdownMenuItem(value: 'Tratado / Restaurado', child: Text('Tratado / Restaurado')),
                                  DropdownMenuItem(value: 'Sano', child: Text('Sano / Sin Patología')),
                                  DropdownMenuItem(value: 'Ausente / Extracción', child: Text('Ausente / Extracción')),
                                ],
                                onChanged: (v) {
                                  if (v != null) provider.setCondition(v);
                                },
                              ),
                              const SizedBox(height: 16),

                              // Nombre del Procedimiento
                              const Text('Procedimiento Planeado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _procedureController,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Notas clínicas
                              const Text('Notas y Observaciones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Observaciones y notas clínicas...',
                                  contentPadding: const EdgeInsets.all(12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Botones de acción
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _notesController.clear();
                                      },
                                      child: const Text('Cancelar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        provider.addFinding(
                                          procedureName: _procedureController.text,
                                          notes: _notesController.text,
                                        );
                                        _notesController.clear();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Hallazgo y tratamiento dental registrado exitosamente.'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                      child: const Text('Guardar Hallazgo'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Resumen de Salud Dental: Índice CPOD (DMFT)
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

  /// Diálogo modal de historial clínico odontológico completo
  void _showDentalHistoryModal(BuildContext context, List<DentalProcedureLog> logs) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.history_edu, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Historial Clínico de Odontología', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Pieza')),
                  DataColumn(label: Text('Procedimiento')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Profesional')),
                ],
                rows: logs.map((log) {
                  final isPending = log.status == 'Pending' || log.status == 'Pendiente';
                  return DataRow(cells: [
                    DataCell(Text('${log.date.day}/${log.date.month}/${log.date.year}')),
                    DataCell(Text('Pieza ${log.toothNumber}')),
                    DataCell(Text(log.procedureName)),
                    DataCell(Text(isPending ? 'Pendiente' : 'Completado', style: TextStyle(color: isPending ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w600))),
                    DataCell(Text(log.providerName)),
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

  /// Diálogo modal para planificar un nuevo tratamiento odontológico
  void _showNewTreatmentModal(BuildContext context, OdontologyProvider provider) {
    final treatmentController = TextEditingController(text: 'Profilaxis y Limpieza Dental con Ultrasonido');
    final costController = TextEditingController(text: '850.00');
    int selectedTooth = provider.selectedTooth;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Planificar Nuevo Tratamiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingrese los datos para agendar o registrar el nuevo procedimiento odontológico:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: treatmentController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Procedimiento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Pieza: $selectedTooth\n${_getToothDescription(selectedTooth)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              onPressed: () {
                provider.addFinding(
                  procedureName: treatmentController.text,
                  notes: 'Planificado con costo estimado de \$${costController.text} MXN.',
                );
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nuevo plan de tratamiento odontológico agregado.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Confirmar Tratamiento'),
            ),
          ],
        );
      },
    );
  }
}
