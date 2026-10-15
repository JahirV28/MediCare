import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/forms/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
    _usernameController.dispose();
    _passwordController.dispose();
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

                    const SizedBox(height: 32),

                    // Username
                    CustomTextField(
                      label: 'Usuario',
                      hintText: 'ID de Proveedor o Email',
                      prefixIcon: Icons.person_outline,
                      controller: _usernameController,
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    CustomTextField(
                      label: 'Contraseña',
                      hintText: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      controller: _passwordController,
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 24),

                    // Login button
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
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return ElevatedButton.icon(
                            onPressed: auth.isLoading ? null : _handleLogin,
                            icon: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.login, size: 20),
                            label: Text(auth.isLoading ? 'Ingresando...' : 'Iniciar Sesión'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            '¿Olvidaste tus credenciales?',
                            style: TextStyle(fontSize: 13, color: AppColors.primaryBlue),
                          ),
                        ),
                        const Text(' / ', style: TextStyle(color: AppColors.textHint)),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Soporte Técnico',
                            style: TextStyle(fontSize: 13, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            context.read<AuthProvider>().clearError();
                            Navigator.pushNamed(context, AppRoutes.register);
                          },
                          child: const Text(
                            'Registrarse',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
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

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.login(
        _usernameController.text,
        _passwordController.text,
        '',
      );
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    }
  }
}
