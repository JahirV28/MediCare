import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/nicaragua_formatters.dart';
import '../../models/patient.dart';
import '../../models/emergency_contact.dart';
import '../../providers/patient_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/forms/custom_text_field.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSaved;

  const PatientRegistrationScreen({
    super.key,
    this.onCancel,
    this.onSaved,
  });

  @override
  State<PatientRegistrationScreen> createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  DateTime? _birthDate;
  String? _birthDateError;
  String? _selectedGender;
  String? _selectedBloodType;
  String? _selectedRelationship;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Breadcrumb(
            items: [
              BreadcrumbItem(label: 'Pacientes', onTap: widget.onCancel),
              const BreadcrumbItem(label: 'Registro de Nuevo Paciente'),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          const Text(
            'Registro de Paciente',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ingrese los datos completos para registrar un nuevo paciente en el sistema.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // Form Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. DATOS PERSONALES (6 Campos Obligatorios) ---
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 22, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Datos Personales (Obligatorios)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Fila 1: Nombre Completo y Cédula (DNI)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Nombre Completo (Solo letras y espacios, obligatorio)
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          label: 'NOMBRE COMPLETO',
                          hintText: 'Ej. Juan José Pérez García',
                          controller: _nameController,
                          isRequired: true,
                          inputFormatters: [NameOnlyLettersFormatter()],
                          validator: NicaraguaValidators.validateFullName,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 2. Número de Identidad / Cédula (Formato Nicaragua: 000-000000-0000A)
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          label: 'CÉDULA DE IDENTIDAD (NICARAGUA)',
                          hintText: '000-000000-0000A',
                          controller: _identityController,
                          isRequired: true,
                          maxLength: 16,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [NicaraguaCedulaFormatter()],
                          validator: NicaraguaValidators.validateCedula,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Fila 2: Fecha de Nacimiento, Género y Teléfono Principal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. Fecha de Nacimiento (Selector de fecha, obligatorio)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'FECHA DE NACIMIENTO',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/yyyy',
                                  suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.textHint),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: _birthDateError != null ? AppColors.danger : AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: _birthDateError != null ? AppColors.danger : AppColors.border,
                                    ),
                                  ),
                                  errorText: _birthDateError,
                                ),
                                child: Text(
                                  _birthDate != null
                                      ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                      : 'Seleccione fecha...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _birthDate != null ? AppColors.textPrimary : AppColors.textHint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 4. Género (Solo Masculino y Femenino, obligatorio)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'GÉNERO',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              hint: const Text('Seleccione...'),
                              validator: (v) => v == null || v.isEmpty ? 'El género es obligatorio' : null,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                                DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedGender = v;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 5. Teléfono Principal (Prefijo Nicaragua: +505 0000 0000, obligatorio)
                      Expanded(
                        child: CustomTextField(
                          label: 'TELÉFONO PRINCIPAL',
                          hintText: '+505 0000 0000',
                          controller: _phoneController,
                          isRequired: true,
                          maxLength: 14,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [NicaraguaPhoneFormatter()],
                          validator: NicaraguaValidators.validatePhone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Fila 3: Dirección de Domicilio y Tipo de Sangre (Opcional)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          label: 'DIRECCIÓN DE DOMICILIO / RESIDENCIA',
                          hintText: 'Ej. Colonia Los Robles, Casa 45, Managua, Nicaragua',
                          controller: _addressController,
                          isRequired: true,
                          validator: NicaraguaValidators.validateAddress,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TIPO DE SANGRE (OPCIONAL)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String?>(
                              initialValue: _selectedBloodType,
                              hint: const Text('Opcional...'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('No especificado')),
                                DropdownMenuItem(value: 'O+', child: Text('O+')),
                                DropdownMenuItem(value: 'O-', child: Text('O-')),
                                DropdownMenuItem(value: 'A+', child: Text('A+')),
                                DropdownMenuItem(value: 'A-', child: Text('A-')),
                                DropdownMenuItem(value: 'B+', child: Text('B+')),
                                DropdownMenuItem(value: 'B-', child: Text('B-')),
                                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedBloodType = v;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- 2. CONTACTO DE EMERGENCIA (3 Campos Opcionales) ---
                  Row(
                    children: [
                      Icon(Icons.contact_phone_outlined, size: 22, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Contacto de Emergencia (Opcional)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Nombre del Contacto (Opcional)
                      Expanded(
                        child: CustomTextField(
                          label: 'NOMBRE DEL CONTACTO',
                          hintText: 'Ej. María Pérez',
                          controller: _emergencyNameController,
                          inputFormatters: [NameOnlyLettersFormatter()],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 2. Parentesco (Opcional)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PARENTESCO',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRelationship,
                              hint: const Text('Seleccione (opcional)...'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Esposo/a', child: Text('Esposo/a')),
                                DropdownMenuItem(value: 'Padre', child: Text('Padre')),
                                DropdownMenuItem(value: 'Madre', child: Text('Madre')),
                                DropdownMenuItem(value: 'Hijo/a', child: Text('Hijo/a')),
                                DropdownMenuItem(value: 'Hermano/a', child: Text('Hermano/a')),
                                DropdownMenuItem(value: 'Tío/a', child: Text('Tío/a')),
                                DropdownMenuItem(value: 'Abuelo/a', child: Text('Abuelo/a')),
                                DropdownMenuItem(value: 'Amigo/a', child: Text('Amigo/a')),
                                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                              ],
                              onChanged: (v) => setState(() => _selectedRelationship = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 3. Teléfono de Emergencia (Opcional, con formato Nicaragua)
                      Expanded(
                        child: CustomTextField(
                          label: 'TELÉFONO DE EMERGENCIA',
                          hintText: '+505 0000 0000',
                          controller: _emergencyPhoneController,
                          maxLength: 14,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [NicaraguaPhoneFormatter()],
                          validator: NicaraguaValidators.validateOptionalPhone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : widget.onCancel,
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar Paciente'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'NI'),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
      });
    }
  }

  void _handleSave() async {
    // Validar fecha de nacimiento
    bool isDateValid = true;
    if (_birthDate == null) {
      setState(() {
        _birthDateError = 'La fecha de nacimiento es obligatoria';
      });
      isDateValid = false;
    } else {
      setState(() {
        _birthDateError = null;
      });
    }

    // Validar formulario
    if (_formKey.currentState!.validate() && isDateValid) {
      setState(() => _isSaving = true);

      try {
        final patient = Patient(
          patientCode: 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          fullName: _nameController.text.trim(),
          identityNumber: _identityController.text.trim().toUpperCase(),
          birthDate: _birthDate,
          gender: _selectedGender,
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          bloodType: _selectedBloodType,
          isActive: true,
          lastVisit: DateTime.now(),
        );

        EmergencyContact? emergency;
        if (_emergencyNameController.text.trim().isNotEmpty ||
            _emergencyPhoneController.text.trim().isNotEmpty ||
            _selectedRelationship != null) {
          emergency = EmergencyContact(
            contactName: _emergencyNameController.text.trim(),
            relationship: _selectedRelationship ?? 'Otro',
            phone: _emergencyPhoneController.text.trim(),
          );
        }

        final patientProvider = context.read<PatientProvider>();
        final success = await patientProvider.createPatient(patient, emergencyContact: emergency);

        if (success && mounted) {
          // Actualizar el Dashboard en tiempo real
          context.read<DashboardProvider>().loadDashboard();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paciente "${patient.fullName}" registrado exitosamente.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onSaved?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar el paciente: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }
}
