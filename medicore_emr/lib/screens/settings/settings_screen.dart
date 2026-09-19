import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/breadcrumb.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Doctor profile
  final _nameController = TextEditingController(text: 'Dr. Alexander Smith');
  final _emailController = TextEditingController(text: 'dr.smith@medicore.com');
  final _phoneController = TextEditingController(text: '+52 55 1234 5678');
  final _specialtyController = TextEditingController(text: 'Medicina General');
  final _licenseController = TextEditingController(text: 'CED-12345678');

  // Clinic info
  final _clinicNameController = TextEditingController(text: 'MediCore Clínica');
  final _clinicAddressController = TextEditingController(text: 'Av. Reforma 123, Col. Centro, CDMX');
  final _clinicPhoneController = TextEditingController(text: '+52 55 9876 5432');
  final _clinicEmailController = TextEditingController(text: 'contacto@medicore.com');

  // Preferences
  bool _notificationsEnabled = true;
  bool _emailReminders = true;
  bool _soundEnabled = true;
  String _language = 'Español';
  String _consultDuration = '30 min';

  int _selectedSection = 0;

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
    super.dispose();
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

          const Text('Configuración', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Administre su perfil, datos de la clínica y preferencias del sistema.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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

  Widget _buildDoctorProfile() {
    return _buildFormCard(
      title: 'Perfil del Doctor',
      subtitle: 'Información personal y profesional del médico.',
      icon: Icons.person_outline,
      children: [
        // Avatar area
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.primaryBlue, width: 3),
                ),
                child: const Center(
                  child: Text('AS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () {}, child: const Text('Cambiar Foto', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFormField('Nombre Completo', _nameController, Icons.badge_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildFormField('Email', _emailController, Icons.email_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Teléfono', _phoneController, Icons.phone_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildFormField('Especialidad', _specialtyController, Icons.medical_services_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Cédula Profesional', _licenseController, Icons.verified_outlined)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildClinicInfo() {
    return _buildFormCard(
      title: 'Datos de la Clínica',
      subtitle: 'Información del establecimiento de salud.',
      icon: Icons.business_outlined,
      children: [
        _buildFormField('Nombre de la Clínica', _clinicNameController, Icons.business_outlined),
        const SizedBox(height: 12),
        _buildFormField('Dirección', _clinicAddressController, Icons.location_on_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildFormField('Teléfono', _clinicPhoneController, Icons.phone_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Email', _clinicEmailController, Icons.email_outlined)),
          ],
        ),
        const SizedBox(height: 20),
        // Horarios
        const Text('Horario de Atención', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...[
          ('Lunes a Viernes', '08:00 — 18:00'),
          ('Sábado', '08:00 — 14:00'),
          ('Domingo', 'Cerrado'),
        ].map((schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(schedule.$1, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                  Text(schedule.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            )),
        const SizedBox(height: 12),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildPreferences() {
    return _buildFormCard(
      title: 'Preferencias',
      subtitle: 'Personalice el comportamiento del sistema.',
      icon: Icons.tune_outlined,
      children: [
        _buildToggleRow('Notificaciones push', 'Recibir alertas de citas y recordatorios.', _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
        const Divider(height: 24),
        _buildToggleRow('Recordatorios por email', 'Enviar emails automáticos a pacientes.', _emailReminders, (v) => setState(() => _emailReminders = v)),
        const Divider(height: 24),
        _buildToggleRow('Sonidos', 'Efectos de sonido en notificaciones.', _soundEnabled, (v) => setState(() => _soundEnabled = v)),
        const Divider(height: 24),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Idioma', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                  const Text('Duración de Consulta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildSecurity() {
    return _buildFormCard(
      title: 'Seguridad',
      subtitle: 'Gestione contraseñas y acceso al sistema.',
      icon: Icons.security_outlined,
      children: [
        _buildFormField('Contraseña Actual', TextEditingController(), Icons.lock_outlined, isPassword: true),
        const SizedBox(height: 12),
        _buildFormField('Nueva Contraseña', TextEditingController(), Icons.lock_outline, isPassword: true),
        const SizedBox(height: 12),
        _buildFormField('Confirmar Nueva Contraseña', TextEditingController(), Icons.lock_outline, isPassword: true),
        const SizedBox(height: 20),
        // Session info
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
              const Text('Información de Sesión', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _buildInfoRow('Último inicio de sesión', '18 Ago 2026, 08:15 AM'),
              _buildInfoRow('Dispositivo', 'Windows 11 — Chrome'),
              _buildInfoRow('IP', '192.168.1.105'),
              _buildInfoRow('Sesiones activas', '1'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSaveButton(label: 'Cambiar Contraseña'),
      ],
    );
  }

  Widget _buildUsersRoles() {
    final users = [
      ('Dr. Alexander Smith', 'Administrador', 'dr.smith@medicore.com', true),
      ('Dra. María López', 'Doctor', 'dra.lopez@medicore.com', true),
      ('Lic. Ana Martínez', 'Enfermera', 'a.martinez@medicore.com', true),
      ('Carlos Ruiz', 'Recepción', 'c.ruiz@medicore.com', false),
    ];

    return _buildFormCard(
      title: 'Usuarios y Roles',
      subtitle: 'Administre el acceso de los usuarios al sistema.',
      icon: Icons.group_outlined,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Agregar Usuario', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Users table header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Usuario', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Expanded(flex: 2, child: Text('Rol', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Expanded(flex: 3, child: Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Expanded(flex: 1, child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Expanded(flex: 1, child: Text('Acciones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            ],
          ),
        ),
        ...users.map((u) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
              child: Row(
                children: [
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
                              u.$1.substring(0, 2).toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(u.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: u.$2 == 'Administrador' ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        u.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: u.$2 == 'Administrador' ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(flex: 3, child: Text(u.$3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: u.$4 ? AppColors.success : AppColors.textHint,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {},
                          child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {},
                          child: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

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

  Widget _buildFormField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
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
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSaveButton({String label = 'Guardar Cambios'}) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cambios guardados exitosamente.'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        icon: const Icon(Icons.check, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _SettingsSection {
  final IconData icon;
  final String label;

  const _SettingsSection({required this.icon, required this.label});
}
