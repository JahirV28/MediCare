import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null || _supabase.auth.currentSession != null;
  String? get error => _error;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      final session = _supabase.auth.currentSession;
      if (session?.user != null) {
        _fetchUserProfile(session!.user);
      }

      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (data.event == AuthChangeEvent.signedIn && session?.user != null) {
          _fetchUserProfile(session!.user);
        } else if (data.event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error al inicializar listener de Supabase Auth: $e');
    }
  }

  /// Inicia sesión utilizando la autenticación nativa de Supabase (`signInWithPassword`).
  /// Admite tanto dirección de correo electrónico como ID de proveedor (ej. DRS-001).
  Future<bool> login(String username, String password, String masterKey) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String emailToUse = username.trim();

      // Si se ingresó un Provider ID en vez de un correo, resolverlo en public.users
      if (!emailToUse.contains('@')) {
        try {
          final userRow = await _supabase
              .from('users')
              .select('email')
              .ilike('provider_id', emailToUse.trim())
              .maybeSingle();

          if (userRow != null && userRow['email'] != null) {
            emailToUse = userRow['email'] as String;
          }
        } catch (e) {
          debugPrint('Aviso: no se pudo resolver provider_id a email: $e');
        }
      }

      // Autenticación nativa Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      final authUser = response.user;
      if (authUser != null) {
        await _fetchUserProfile(authUser);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Credenciales inválidas. Por favor intenta de nuevo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _error = _mapAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error de conexión. Intente nuevamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Valida o auto-genera un ID de Proveedor (ej. DRS-001, DRM-002, NUR-001, ADM-001).
  Future<String> _resolveOrGenerateProviderId({
    String? customProviderId,
    required String role,
    required String fullName,
  }) async {
    if (customProviderId != null && customProviderId.trim().isNotEmpty) {
      final cleanId = customProviderId.trim().toUpperCase();
      try {
        final existing = await _supabase
            .from('users')
            .select('id')
            .ilike('provider_id', cleanId)
            .maybeSingle();
        if (existing != null) {
          throw 'El ID de Proveedor "$cleanId" ya está en uso. Por favor elija otro.';
        }
      } catch (e) {
        if (e is String) rethrow;
        debugPrint('Aviso al verificar provider_id existente: $e');
      }
      return cleanId;
    }

    // Auto-generación coherente según rol y nombre
    final roleNormalized = role.toLowerCase().trim();
    String prefix;
    if (roleNormalized.contains('doc') || roleNormalized.contains('méd') || roleNormalized.contains('med')) {
      final cleanName = fullName.trim().replaceAll(RegExp(r'^(dr\.|dra\.)\s*', caseSensitive: false), '');
      final parts = cleanName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      final initial = parts.length > 1 ? parts.last[0].toUpperCase() : (parts.isNotEmpty ? parts.first[0].toUpperCase() : 'M');
      prefix = 'DR$initial';
    } else if (roleNormalized.contains('nur') || roleNormalized.contains('enf')) {
      prefix = 'NUR';
    } else if (roleNormalized.contains('adm')) {
      prefix = 'ADM';
    } else if (roleNormalized.contains('rec')) {
      prefix = 'REC';
    } else {
      prefix = 'MED';
    }

    try {
      final existing = await _supabase
          .from('users')
          .select('provider_id')
          .ilike('provider_id', '$prefix-%');

      int maxNum = 0;
      for (var row in existing) {
        final pid = row['provider_id'] as String?;
        if (pid != null) {
          final parts = pid.split('-');
          if (parts.length > 1) {
            final n = int.tryParse(parts[1]);
            if (n != null && n > maxNum) maxNum = n;
          }
        }
      }
      final nextNum = (maxNum + 1).toString().padLeft(3, '0');
      return '$prefix-$nextNum';
    } catch (_) {
      final rand = (DateTime.now().millisecondsSinceEpoch % 900 + 100);
      return '$prefix-$rand';
    }
  }

  /// Registra una nueva cuenta usando `supabase.auth.signUp`.
  /// Adicionalmente registra el perfil completo en `public.users` garantizando provider_id e integridad relacional.
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? providerId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final roleId = _mapRoleNameToId(role);
      final finalProviderId = await _resolveOrGenerateProviderId(
        customProviderId: providerId,
        role: role,
        fullName: fullName,
      );

      // Registro nativo con Supabase Auth guardando metadatos completos
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role,
          'role_id': roleId,
          'provider_id': finalProviderId,
        },
      );

      final authUser = response.user;
      if (authUser != null) {
        // Sincronizar en la tabla public.users con provider_id
        try {
          await _supabase.from('users').insert({
            'auth_user_id': authUser.id,
            'full_name': fullName.trim(),
            'email': email.trim(),
            'provider_id': finalProviderId,
            'password_hash': '[supabase_auth]',
            'role_id': roleId,
            'is_active': true,
          });
        } catch (dbError) {
          debugPrint('Error al insertar en public.users: $dbError');
          final errStr = dbError.toString();
          if (errStr.contains('provider_id') || errStr.contains('duplicate key')) {
            _error = 'El ID de Proveedor "$finalProviderId" o el correo ya se encuentra registrado.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'No se pudo completar el registro.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _error = _mapAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión activa en Supabase y limpia el estado local.
  void logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error en signOut: $e');
    }
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Limpia cualquier mensaje de error activo.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Obtiene o mapea los detalles de perfil del usuario desde Supabase o sus metadatos.
  Future<void> _fetchUserProfile(dynamic authUser) async {
    try {
      final record = await _supabase
          .from('users')
          .select('*, roles(name)')
          .or('auth_user_id.eq.${authUser.id},email.eq.${authUser.email}')
          .maybeSingle();

      if (record != null) {
        final map = Map<String, dynamic>.from(record);
        if (map['roles'] != null && map['roles'] is Map) {
          map['role_name'] = map['roles']['name'];
        }
        _currentUser = User.fromMap(map);

        // Si provider_id estaba nulo en BD, auto-asignarlo y actualizar
        if (record['provider_id'] == null) {
          final metadata = (authUser.userMetadata as Map<String, dynamic>?) ?? {};
          final metaProviderId = metadata['provider_id'] as String?;
          final resolvedProviderId = metaProviderId ??
              await _resolveOrGenerateProviderId(
                role: map['role_name'] ?? 'Doctor',
                fullName: _currentUser!.fullName,
              );
          await _supabase.from('users').update({
            'provider_id': resolvedProviderId,
            'auth_user_id': authUser.id,
            'last_login': DateTime.now().toIso8601String(),
          }).eq('id', record['id']);
          _currentUser = _currentUser!.copyWith(providerId: resolvedProviderId);
        } else if (record['auth_user_id'] == null) {
          await _supabase.from('users').update({
            'auth_user_id': authUser.id,
            'last_login': DateTime.now().toIso8601String(),
          }).eq('id', record['id']);
        } else {
          await _supabase.from('users').update({
            'last_login': DateTime.now().toIso8601String(),
          }).eq('id', record['id']);
        }
      } else {
        final metadata = (authUser.userMetadata as Map<String, dynamic>?) ?? {};
        final roleName = metadata['role'] as String? ?? 'Doctor';
        final fullName = metadata['full_name'] as String? ?? authUser.email?.split('@').first ?? 'Usuario';
        final providerId = metadata['provider_id'] as String?;
        _currentUser = User(
          fullName: fullName,
          email: authUser.email ?? '',
          providerId: providerId,
          roleId: _mapRoleNameToId(roleName),
          roleName: roleName,
          isActive: true,
          lastLogin: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error al obtener perfil desde BD: $e');
      final metadata = (authUser.userMetadata as Map<String, dynamic>?) ?? {};
      final roleName = metadata['role'] as String? ?? 'Doctor';
      final fullName = metadata['full_name'] as String? ?? authUser.email?.split('@').first ?? 'Usuario';
      final providerId = metadata['provider_id'] as String?;
      _currentUser = User(
        fullName: fullName,
        email: authUser.email ?? '',
        providerId: providerId,
        roleId: _mapRoleNameToId(roleName),
        roleName: roleName,
        isActive: true,
        lastLogin: DateTime.now(),
      );
    }
  }

  int _mapRoleNameToId(String roleName) {
    switch (roleName.toLowerCase().trim()) {
      case 'admin':
      case 'administrador':
        return 1;
      case 'doctor':
      case 'médico':
      case 'medico':
        return 2;
      case 'nurse':
      case 'enfermero':
      case 'enfermera':
        return 3;
      case 'reception':
      case 'recepción':
      case 'recepcion':
        return 4;
      default:
        return 2;
    }
  }

  String _mapAuthErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'Credenciales inválidas. Por favor intenta de nuevo.';
    }
    if (lower.contains('user already registered') || lower.contains('already exists')) {
      return 'Este correo electrónico ya se encuentra registrado.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Correo no confirmado. Por favor revisa tu bandeja de entrada.';
    }
    if (lower.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return message;
  }

  Future<bool> updateDoctorProfile({
    required String fullName,
    required String email,
    String? phone,
    String? specialty,
    String? licenseNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uid = _currentUser?.id;
      final updateData = <String, dynamic>{
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'specialty': specialty?.trim(),
        'license_number': licenseNumber?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (uid != null && uid > 0) {
        await _supabase.from('users').update(updateData).eq('id', uid);
      } else if (_currentUser?.email != null) {
        await _supabase.from('users').update(updateData).eq('email', _currentUser!.email);
      }

      _currentUser = _currentUser?.copyWith(
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone?.trim(),
        specialty: specialty?.trim(),
        licenseNumber: licenseNumber?.trim(),
      ) ?? User(
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone?.trim(),
        specialty: specialty?.trim(),
        licenseNumber: licenseNumber?.trim(),
        roleId: 2,
        roleName: 'Doctor',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword.trim()));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al cambiar contraseña: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
