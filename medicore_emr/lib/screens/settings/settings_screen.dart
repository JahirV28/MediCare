import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/breadcrumb.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _api = SupabaseService();
  int _selectedSection = 0;

  // ── Doctor Profile Controllers ──
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _specialtyController;
  late TextEditingController _licenseController;
  bool _doctorProfileInitialized = false;
  bool _isSavingDoctor = false;

  // ── Clinic Info Controllers ──
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicPhoneController = TextEditingController();
  final _clinicEmailController = TextEditingController();
  final _scheduleWeekdayController = TextEditingController(text: '08:00 — 18:00');
  final _scheduleSaturdayController = TextEditingController(text: '08:00 — 14:00');
  final _scheduleSundayController = TextEditingController(text: 'Cerrado');
  bool _isLoadingClinic = true;
  bool _isSavingClinic = false;

  // ── Preferences State ──
  bool _notificationsEnabled = true;
  bool _emailReminders = true;
  bool _soundEnabled = true;
  String _language = 'Español';
  String _consultDuration = '30 min';
  bool _isSavingPreferences = false;

  // ── Security Controllers ──
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;

  // ── Users & Roles State ──
  List<User> _systemUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _specialtyController = TextEditingController();
    _licenseController = TextEditingController();

    _loadClinicSettings();
    _loadSystemUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_doctorProfileInitialized) {
      final user = context.watch<AuthProvider>().currentUser;
      if (user != null) {
        _nameController.text = user.fullName;
        _emailController.text = user.email;
        _phoneController.text = user.phone ?? '';
        _specialtyController.text = user.specialty ?? '';
        _licenseController.text = user.licenseNumber ?? user.providerId ?? '';
        _doctorProfileInitialized = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _licenseController.dispose();

    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    _scheduleWeekdayController.dispose();
    _scheduleSaturdayController.dispose();
    _scheduleSundayController.dispose();

    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadClinicSettings() async {
    setState(() => _isLoadingClinic = true);
    try {
      final settings = await _api.getClinicSettings();
      if (mounted) {
        setState(() {
          _clinicNameController.text = settings['clinic_name']?.toString() ?? 'MediCore Clínica';
          _clinicAddressController.text = settings['address']?.toString() ?? '';
          _clinicPhoneController.text = settings['phone']?.toString() ?? '';
          _clinicEmailController.text = settings['email']?.toString() ?? '';
          _scheduleWeekdayController.text = settings['schedule_weekday']?.toString() ?? '08:00 — 18:00';
          _scheduleSaturdayController.text = settings['schedule_saturday']?.toString() ?? '08:00 — 14:00';
          _scheduleSundayController.text = settings['schedule_sunday']?.toString() ?? 'Cerrado';

          _notificationsEnabled = settings['notifications_enabled'] == true || settings['notifications_enabled'] == 1;
          _emailReminders = settings['email_reminders'] == true || settings['email_reminders'] == 1;
          _soundEnabled = settings['sound_enabled'] == true || settings['sound_enabled'] == 1;
          _language = settings['language']?.toString() ?? 'Español';
          _consultDuration = settings['consult_duration']?.toString() ?? '30 min';
          _isLoadingClinic = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingClinic = false);
    }
  }

  Future<void> _loadSystemUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final List<User> users = await _api.getSystemUsers();
      if (mounted) {
        setState(() {
          _systemUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

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
              const BreadcrumbItem(label: 'Configuración'),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Configuración',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Administre su perfil profesional, datos de la clínica y preferencias conectadas a Supabase.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section tabs
              SizedBox(
                width: 220,
                child: _buildSectionNav(),
              ),
              const SizedBox(width: 24),
              // Content
              Expanded(
                child: _buildSectionContent(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionNav() {
    final sections = [
      _SettingsSection(icon: Icons.person_outline, label: 'Perfil del Doctor'),
      _SettingsSection(icon: Icons.business_outlined, label: 'Datos de la Clínica'),
      _SettingsSection(icon: Icons.tune_outlined, label: 'Preferencias'),
      _SettingsSection(icon: Icons.security_outlined, label: 'Seguridad'),
      _SettingsSection(icon: Icons.group_outlined, label: 'Usuarios y Roles'),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(sections.length, (index) {
          final section = sections[index];
          final isActive = _selectedSection == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => setState(() => _selectedSection = index),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryBlue.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isActive ? Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(section.icon, size: 20, color: isActive ? AppColors.primaryBlue : AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0:
        return _buildDoctorProfile();
      case 1:
        return _buildClinicInfo();
      case 2:
        return _buildPreferences();
      case 3:
        return _buildSecurity();
      case 4:
        return _buildUsersRoles();
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. PERFIL DEL DOCTOR (DATOS REALES DEL USUARIO ACTIVO)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorProfile() {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final initials = user?.initials ?? 'DR';
    final roleName = user?.roleName ?? 'Médico';
    final providerId = user?.providerId ?? '';

    return _buildFormCard(
      title: 'Perfil del Doctor',
      subtitle: 'Información personal y credenciales del médico con sesión activa.',
      icon: Icons.person_outline,
      children: [
        // Avatar del médico autenticado
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.primaryBlue, width: 3),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roleName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                    ),
                  ),
                  if (providerId.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '•  ID: $providerId',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildFormField('Nombre Completo *', _nameController, Icons.badge_outlined),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(child: _buildFormField('Email *', _emailController, Icons.email_outlined, enabled: false)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Teléfono', _phoneController, Icons.phone_outlined, hint: 'Ej. +52 55 1234 5678')),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(child: _buildFormField('Especialidad', _specialtyController, Icons.medical_services_outlined, hint: 'Ej. Medicina General / Odontología')),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Cédula Profesional', _licenseController, Icons.verified_outlined, hint: 'Ej. CED-12345678')),
          ],
        ),
        const SizedBox(height: 24),

        _buildActionSaveButton(
          isLoading: _isSavingDoctor,
          label: 'Guardar Perfil',
          onPressed: _saveDoctorProfile,
        ),
      ],
    );
  }

  Future<void> _saveDoctorProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showFeedbackSnackBar('Por favor ingresa tu nombre completo.', isError: true);
      return;
    }

    setState(() => _isSavingDoctor = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.updateDoctorProfile(
      fullName: name,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      specialty: _specialtyController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSavingDoctor = false);
      if (success) {
        _showFeedbackSnackBar('Perfil del doctor actualizado exitosamente en Supabase.');
      } else {
        _showFeedbackSnackBar(auth.error ?? 'Error al actualizar el perfil.', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. DATOS DE LA CLÍNICA (CONECTADO A SUPABASE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildClinicInfo() {
    if (_isLoadingClinic) {
      return _buildLoadingCard('Cargando información de la clínica...');
    }

    return _buildFormCard(
      title: 'Datos de la Clínica',
      subtitle: 'Información oficial del establecimiento y horarios de atención.',
      icon: Icons.business_outlined,
      children: [
        _buildFormField('Nombre de la Clínica *', _clinicNameController, Icons.business_outlined),
        const SizedBox(height: 14),
        _buildFormField('Dirección Física', _clinicAddressController, Icons.location_on_outlined, hint: 'Calle, número, colonia y ciudad'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildFormField('Teléfono de Contacto', _clinicPhoneController, Icons.phone_outlined, hint: 'Teléfono de recepción')),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Email Institucional', _clinicEmailController, Icons.email_outlined, hint: 'contacto@clinica.com')),
          ],
        ),
        const SizedBox(height: 24),

        const Text('Horario de Atención', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: _buildFormField('Lunes a Viernes', _scheduleWeekdayController, Icons.schedule, hint: '08:00 — 18:00')),
            const SizedBox(width: 12),
            Expanded(child: _buildFormField('Sábados', _scheduleSaturdayController, Icons.schedule, hint: '08:00 — 14:00')),
            const SizedBox(width: 12),
            Expanded(child: _buildFormField('Domingos', _scheduleSundayController, Icons.schedule, hint: 'Cerrado')),
          ],
        ),
        const SizedBox(height: 24),

        _buildActionSaveButton(
          isLoading: _isSavingClinic,
          label: 'Guardar Datos de la Clínica',
          onPressed: _saveClinicInfo,
        ),
      ],
    );
  }

  Future<void> _saveClinicInfo() async {
    final name = _clinicNameController.text.trim();
    if (name.isEmpty) {
      _showFeedbackSnackBar('Por favor ingresa el nombre de la clínica.', isError: true);
      return;
    }

    setState(() => _isSavingClinic = true);
    final ok = await _api.saveClinicSettings({
      'clinic_name': name,
      'address': _clinicAddressController.text.trim(),
      'phone': _clinicPhoneController.text.trim(),
      'email': _clinicEmailController.text.trim(),
      'schedule_weekday': _scheduleWeekdayController.text.trim(),
      'schedule_saturday': _scheduleSaturdayController.text.trim(),
      'schedule_sunday': _scheduleSundayController.text.trim(),
      'notifications_enabled': _notificationsEnabled,
      'email_reminders': _emailReminders,
      'sound_enabled': _soundEnabled,
      'language': _language,
      'consult_duration': _consultDuration,
    });

    if (mounted) {
      setState(() => _isSavingClinic = false);
      if (ok) {
        _showFeedbackSnackBar('Datos de la clínica guardados exitosamente en Supabase.');
      } else {
        _showFeedbackSnackBar('Error al guardar los datos de la clínica.', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. PREFERENCIAS DEL SISTEMA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPreferences() {
    return _buildFormCard(
      title: 'Preferencias',
      subtitle: 'Ajustes de alertas, idioma y parámetros operativos.',
      icon: Icons.tune_outlined,
      children: [
        _buildToggleRow(
          'Notificaciones push',
          'Recibir alertas sonoras y visuales de citas y pacientes en espera.',
          _notificationsEnabled,
          (v) => setState(() => _notificationsEnabled = v),
        ),
        const Divider(height: 24),
        _buildToggleRow(
          'Recordatorios por email',
          'Enviar correos de confirmación y recordatorios a pacientes registrados.',
          _emailReminders,
          (v) => setState(() => _emailReminders = v),
        ),
        const Divider(height: 24),
        _buildToggleRow(
          'Sonidos del sistema',
          'Reproducir efectos sonoros para confirmaciones y alertas médicas.',
          _soundEnabled,
          (v) => setState(() => _soundEnabled = v),
        ),
        const Divider(height: 24),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Idioma del Sistema', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: ['Español', 'English'].map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() => _language = val ?? 'Español'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duración Promedio de Consulta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _consultDuration,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: ['15 min', '20 min', '30 min', '45 min', '60 min'].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() => _consultDuration = val ?? '30 min'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildActionSaveButton(
          isLoading: _isSavingPreferences,
          label: 'Guardar Preferencias',
          onPressed: _savePreferences,
        ),
      ],
    );
  }

  Future<void> _savePreferences() async {
    setState(() => _isSavingPreferences = true);
    final ok = await _api.saveClinicSettings({
      'clinic_name': _clinicNameController.text.trim().isNotEmpty ? _clinicNameController.text.trim() : 'MediCore Clínica',
      'address': _clinicAddressController.text.trim(),
      'phone': _clinicPhoneController.text.trim(),
      'email': _clinicEmailController.text.trim(),
      'schedule_weekday': _scheduleWeekdayController.text.trim(),
      'schedule_saturday': _scheduleSaturdayController.text.trim(),
      'schedule_sunday': _scheduleSundayController.text.trim(),
      'notifications_enabled': _notificationsEnabled,
      'email_reminders': _emailReminders,
      'sound_enabled': _soundEnabled,
      'language': _language,
      'consult_duration': _consultDuration,
    });

    if (mounted) {
      setState(() => _isSavingPreferences = false);
      if (ok) {
        _showFeedbackSnackBar('Preferencias guardadas exitosamente en la base de datos.');
      } else {
        _showFeedbackSnackBar('Error al guardar las preferencias.', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. SEGURIDAD Y ACCESO (SESIÓN REAL Y CAMBIO DE CONTRASEÑA EN SUPABASE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSecurity() {
    final user = context.watch<AuthProvider>().currentUser;
    final osName = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;

    String lastLoginDisplay = 'Sesión iniciada';
    if (user?.lastLogin != null) {
      final dt = user!.lastLogin!;
      lastLoginDisplay = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return _buildFormCard(
      title: 'Seguridad de la Cuenta',
      subtitle: 'Gestione su contraseña de acceso y consulte los detalles de su sesión activa.',
      icon: Icons.security_outlined,
      children: [
        _buildPasswordField('Nueva Contraseña *', _newPasswordController, _obscureNew, () {
          setState(() => _obscureNew = !_obscureNew);
        }),
        const SizedBox(height: 14),
        _buildPasswordField('Confirmar Nueva Contraseña *', _confirmPasswordController, _obscureConfirm, () {
          setState(() => _obscureConfirm = !_obscureConfirm);
        }),
        const SizedBox(height: 20),

        // Session info con datos reales
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Información de la Sesión Activa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Autenticado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Usuario conectado', '${user?.fullName ?? "Usuario"} (${user?.email ?? ""})'),
              _buildInfoRow('Rol y Cédula/ID', '${user?.roleName ?? "Doctor"} • ID: ${user?.providerId ?? "N/A"}'),
              _buildInfoRow('Dispositivo / Sistema', '${osName.toUpperCase()} — $osVersion'),
              _buildInfoRow('Último acceso registrado', lastLoginDisplay),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildActionSaveButton(
          isLoading: _isChangingPassword,
          label: 'Actualizar Contraseña',
          onPressed: _changePassword,
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty) {
      _showFeedbackSnackBar('Por favor ingresa la nueva contraseña.', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showFeedbackSnackBar('La nueva contraseña debe tener al menos 6 caracteres.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showFeedbackSnackBar('Las contraseñas no coinciden. Por favor verifícalas.', isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(newPass);

    if (mounted) {
      setState(() => _isChangingPassword = false);
      if (success) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showFeedbackSnackBar('Contraseña actualizada exitosamente en Supabase Auth.');
      } else {
        _showFeedbackSnackBar(auth.error ?? 'Error al actualizar la contraseña.', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5. USUARIOS Y ROLES (DATOS REALES DE LA TABLA USERS DE SUPABASE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUsersRoles() {
    return _buildFormCard(
      title: 'Usuarios y Roles',
      subtitle: 'Administre los usuarios registrados en la base de datos de Supabase.',
      icon: Icons.group_outlined,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_systemUsers.length} usuarios registrados',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Agregar Usuario', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoadingUsers)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
              ),
            ),
          )
        else if (_systemUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.group_off_outlined, size: 36, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  const Text('No se encontraron usuarios registrados en la base de datos.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadSystemUsers,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Recargar'),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Usuario', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Rol / ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                      Expanded(flex: 3, child: Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                      Expanded(flex: 1, child: Center(child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)))),
                      Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Acciones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)))),
                    ],
                  ),
                ),
                // Table rows
                ..._systemUsers.map((u) {
                  final role = u.roleName ?? (u.roleId == 1 ? 'Administrador' : 'Doctor');
                  final isAdmin = role.toLowerCase().contains('admin');
                  final isDoctor = role.toLowerCase().contains('doc') || role.toLowerCase().contains('méd');

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Row(
                      children: [
                        // Usuario / Avatar
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                ),
                                child: Center(
                                  child: Text(
                                    u.initials,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  u.fullName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Rol / ID
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? AppColors.primaryBlue.withValues(alpha: 0.1)
                                      : (isDoctor ? AppColors.successLight : AppColors.background),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isAdmin ? AppColors.primaryBlue : (isDoctor ? AppColors.success : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              if (u.providerId != null && u.providerId!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    u.providerId!,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Email
                        Expanded(
                          flex: 3,
                          child: Text(
                            u.email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Estado
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: u.isActive ? AppColors.success : AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                        // Acciones
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                                tooltip: 'Editar Usuario',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => _showEditUserDialog(u),
                              ),
                              IconButton(
                                icon: Icon(
                                  u.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                  size: 16,
                                  color: u.isActive ? AppColors.danger : AppColors.success,
                                ),
                                tooltip: u.isActive ? 'Desactivar Usuario' : 'Activar Usuario',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => _confirmToggleUser(u),
                              ),
                            ],
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
    );
  }

  // ── Modales de Usuarios ──

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    int selectedRoleId = 2; // Doctor por defecto

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: AppColors.primaryBlue, size: 22),
              SizedBox(width: 8),
              Text('Registrar Nuevo Usuario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogField('Nombre Completo *', nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildDialogField('Email *', emailCtrl, Icons.email_outlined),
                  const SizedBox(height: 12),
                  const Text('Rol en el Sistema *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedRoleId,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Administrador')),
                      DropdownMenuItem(value: 2, child: Text('Doctor / Médico')),
                      DropdownMenuItem(value: 3, child: Text('Enfermera')),
                      DropdownMenuItem(value: 4, child: Text('Recepción')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedRoleId = val ?? 2),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField('Teléfono', phoneCtrl, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField('Especialidad', specialtyCtrl, Icons.medical_services_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField('Cédula Profesional', licenseCtrl, Icons.verified_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField('Contraseña Inicial *', passwordCtrl, Icons.lock_outline, isPassword: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final pass = passwordCtrl.text.trim();
                if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa los campos obligatorios (*).'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                final ok = await _api.createSystemUser(
                  fullName: name,
                  email: email,
                  roleId: selectedRoleId,
                  phone: phoneCtrl.text.trim(),
                  specialty: specialtyCtrl.text.trim(),
                  licenseNumber: licenseCtrl.text.trim(),
                  password: pass,
                );

                if (ok) {
                  _showFeedbackSnackBar('Usuario creado exitosamente en la base de datos.');
                  _loadSystemUsers();
                } else {
                  _showFeedbackSnackBar('Error al registrar usuario en Supabase.', isError: true);
                }
              },
              child: const Text('Registrar Usuario'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(User user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final specialtyCtrl = TextEditingController(text: user.specialty ?? '');
    final licenseCtrl = TextEditingController(text: user.licenseNumber ?? '');
    int selectedRoleId = user.roleId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, color: AppColors.primaryBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Editar Usuario: ${user.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogField('Nombre Completo *', nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                  const Text('Rol en el Sistema *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedRoleId,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Administrador')),
                      DropdownMenuItem(value: 2, child: Text('Doctor / Médico')),
                      DropdownMenuItem(value: 3, child: Text('Enfermera')),
                      DropdownMenuItem(value: 4, child: Text('Recepción')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedRoleId = val ?? user.roleId),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField('Teléfono', phoneCtrl, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField('Especialidad', specialtyCtrl, Icons.medical_services_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField('Cédula Profesional', licenseCtrl, Icons.verified_outlined),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || user.id == null) return;

                Navigator.pop(dialogCtx);
                final ok = await _api.updateSystemUser(
                  userId: user.id!,
                  fullName: name,
                  email: user.email,
                  roleId: selectedRoleId,
                  phone: phoneCtrl.text.trim(),
                  specialty: specialtyCtrl.text.trim(),
                  licenseNumber: licenseCtrl.text.trim(),
                );

                if (ok) {
                  _showFeedbackSnackBar('Usuario actualizado exitosamente.');
                  _loadSystemUsers();
                } else {
                  _showFeedbackSnackBar('Error al actualizar usuario.', isError: true);
                }
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmToggleUser(User user) {
    if (user.id == null) return;
    final newStatus = !user.isActive;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(newStatus ? 'Activar Usuario' : 'Desactivar Usuario'),
        content: Text(
          newStatus
              ? '¿Desea reactivar el acceso de "${user.fullName}" al sistema?'
              : '¿Desea desactivar el acceso de "${user.fullName}"? El usuario no podrá iniciar sesión.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.danger,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await _api.toggleUserStatus(user.id!, newStatus);
              if (ok) {
                _showFeedbackSnackBar('Estado del usuario actualizado exitosamente.');
                _loadSystemUsers();
              } else {
                _showFeedbackSnackBar('Error al cambiar el estado del usuario.', isError: true);
              }
            },
            child: Text(newStatus ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFormCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
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
            children: [
              Icon(icon, size: 22, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(fontSize: 13, color: enabled ? AppColors.textPrimary : AppColors.textHint),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            fillColor: enabled ? AppColors.background : AppColors.borderLight.withValues(alpha: 0.3),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure, VoidCallback onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outlined, size: 18, color: AppColors.textHint),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AppColors.textHint),
              onPressed: onToggle,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryBlue),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSaveButton({
    required bool isLoading,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
            : const Icon(Icons.check, size: 18),
        label: Text(label),
      ),
    );
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: AppColors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SettingsSection {
  final IconData icon;
  final String label;

  const _SettingsSection({required this.icon, required this.label});
}
