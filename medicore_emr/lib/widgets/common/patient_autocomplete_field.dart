import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/patient.dart';
import '../../services/supabase_service.dart';

class PatientAutocompleteField extends StatefulWidget {
  final Function(Patient? patient) onPatientSelected;
  final Patient? initialPatient;
  final String label;
  final String hint;

  const PatientAutocompleteField({
    super.key,
    required this.onPatientSelected,
    this.initialPatient,
    this.label = 'Nombre del Paciente *',
    this.hint = 'Escriba las primeras letras del nombre o código...',
  });

  @override
  State<PatientAutocompleteField> createState() => _PatientAutocompleteFieldState();
}

class _PatientAutocompleteFieldState extends State<PatientAutocompleteField> {
  final SupabaseService _api = SupabaseService();
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;

  List<Patient> _suggestions = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  Patient? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPatient?.fullName ?? '');
    _selectedPatient = widget.initialPatient;
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _search(_controller.text);
      } else {
        // Retrasar el cierre para permitir el tap en las sugerencias
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_focusNode.hasFocus) {
            setState(() => _showDropdown = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_selectedPatient != null && _selectedPatient!.fullName != value) {
      setState(() {
        _selectedPatient = null;
      });
      widget.onPatientSelected(null);
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _showDropdown = true;
    });

    try {
      final results = await _api.searchPatients(query, limit: 6);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _controller.text = patient.fullName;
      _showDropdown = false;
    });
    widget.onPatientSelected(patient);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
      _controller.clear();
      _suggestions.clear();
      _showDropdown = false;
    });
    widget.onPatientSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de texto
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.person_search_outlined, color: AppColors.primaryBlue, size: 22),
            suffixIcon: _buildSuffixIcon(),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _selectedPatient != null ? AppColors.success : AppColors.border,
                width: _selectedPatient != null ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2.0),
            ),
          ),
        ),

        // Badge de paciente seleccionado verificado
        if (_selectedPatient != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registrado en BD: ${_selectedPatient!.patientCode} • ${_selectedPatient!.fullName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: _clearSelection,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_controller.text.isNotEmpty && !_showDropdown) ...[
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'Debe seleccionar un paciente registrado de la lista desplegable.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],

        // Lista desplegable de sugerencias
        if (_showDropdown && _focusNode.hasFocus) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                      ),
                    ),
                  )
                : _suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.person_off_outlined, size: 18, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'No se encontraron pacientes registrados con ese nombre.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final patient = _suggestions[index];
                          return InkWell(
                            onTap: () => _selectPatient(patient),
                            hoverColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    child: Text(
                                      patient.initials,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patient.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${patient.patientCode} • ${patient.phone ?? patient.identityNumber ?? "Sin teléfono"}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (patient.hasAlert)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.dangerLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Alerta',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textHint),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
        ),
      );
    }
    if (_selectedPatient != null) {
      return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
    }
    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
        onPressed: _clearSelection,
      );
    }
    return null;
  }
}
