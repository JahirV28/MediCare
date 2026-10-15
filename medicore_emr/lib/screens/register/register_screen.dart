import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/forms/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _providerIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'Doctor';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().clearError();
      }
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _providerIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Container(
              width: 440,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MediCore EMR',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Crear Nueva Cuenta',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full Name
                    CustomTextField(
                      label: 'Nombre Completo',
                      hintText: 'Ej. Dr. Juan Pérez',
                      prefixIcon: Icons.person_outline,
                      controller: _nameController,
                      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 18),

                    // Email
                    CustomTextField(
                      label: 'Correo Electrónico',
                      hintText: 'correo@medicore.com',
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Provider ID
                    CustomTextField(
                      label: 'ID de Proveedor',
                      hintText: _selectedRole == 'Doctor'
                          ? 'Ej. DRS-001 (Opcional, se autogenera)'
                          : _selectedRole == 'Nurse'
                              ? 'Ej. NUR-001 (Opcional, se autogenera)'
                              : _selectedRole == 'Admin'
                                  ? 'Ej. ADM-001 (Opcional, se autogenera)'
                                  : 'Ej. REC-001 (Opcional, se autogenera)',
                      prefixIcon: Icons.badge_outlined,
                      controller: _providerIdController,
                    ),
                    const SizedBox(height: 18),

                    // Role dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rol',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 20, color: AppColors.textHint),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Admin', child: Text('Administrador')),
                            DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
                            DropdownMenuItem(value: 'Nurse', child: Text('Enfermero/a')),
                            DropdownMenuItem(value: 'Reception', child: Text('Recepción')),
                          ],
                          onChanged: (v) => setState(() => _selectedRole = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Password
                    CustomTextField(
                      label: 'Contraseña',
                      hintText: 'Mínimo 8 caracteres',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      controller: _passwordController,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (v.length < 8) return 'Mínimo 8 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Confirm Password
                    CustomTextField(
                      label: 'Confirmar Contraseña',
                      hintText: 'Repite tu contraseña',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureConfirm,
                      suffixIcon: _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      controller: _confirmPasswordController,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Error
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.error != null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              auth.error!,
                              style: const TextStyle(fontSize: 13, color: AppColors.danger),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return ElevatedButton.icon(
                            onPressed: auth.isLoading ? null : _handleRegister,
                            icon: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add_outlined, size: 20),
                            label: Text(auth.isLoading ? 'Creando cuenta...' : 'Crear Cuenta'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes cuenta? ',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            context.read<AuthProvider>().clearError();
                            Navigator.pushReplacementNamed(context, AppRoutes.login);
                          },
                          child: const Text(
                            'Iniciar Sesión',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // HIPAA notice
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        const Text(
                          'HIPAA Compliant System',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Unauthorized access is strictly prohibited and monitored.',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        providerId: _providerIdController.text.trim().isEmpty ? null : _providerIdController.text.trim(),
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente! Ya puedes iniciar sesión con tu correo o ID de Proveedor.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }
}
