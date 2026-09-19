import 'package:flutter/services.dart';

/// Formateador para Cédula de Identidad de Nicaragua: 000-000000-0000A
/// (14 caracteres alfanuméricos + 2 guiones = 16 caracteres totales)
/// Ejemplo: 001-280590-0004X
class NicaraguaCedulaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si el usuario borra texto, permitimos la acción
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final raw = newValue.text.toUpperCase();
    final buffer = StringBuffer();
    int digitCount = 0;

    for (int i = 0; i < raw.length; i++) {
      final char = raw[i];

      // Los primeros 13 caracteres deben ser dígitos numéricos (0-9)
      if (digitCount < 13) {
        if (RegExp(r'[0-9]').hasMatch(char)) {
          if (digitCount == 3) buffer.write('-');
          if (digitCount == 9) buffer.write('-');
          buffer.write(char);
          digitCount++;
        }
      }
      // El 14vo carácter es la letra final (A-Z)
      else if (digitCount == 13) {
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          buffer.write(char);
          digitCount++;
          break; // Longitud máxima alcanzada
        }
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formateador para Números Telefónicos de Nicaragua: +505 0000 0000
/// (Prefijo +505 seguido de 8 dígitos divididos en 2 bloques de 4)
class NicaraguaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si se borra texto, permitimos la acción
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // Extraer únicamente los dígitos numéricos
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Si comienza con 505, quitarlo para normalizar los 8 dígitos locales
    if (digitsOnly.startsWith('505')) {
      digitsOnly = digitsOnly.substring(3);
    }

    // Limitar a 8 dígitos máximos
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }

    final buffer = StringBuffer('+505 ');

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 4) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formateador para permitir únicamente letras, tildes, diéresis y espacios (sin números)
class NameOnlyLettersFormatter extends TextInputFormatter {
  static final RegExp _allowedPattern = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_allowedPattern.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

/// Validadores de formulario para el estándar clínico y de Nicaragua
class NicaraguaValidators {
  /// Validador de nombre completo (obligatorio, solo letras, mínimo 3 caracteres)
  static String? validateFullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'El nombre completo es obligatorio';
    }
    if (v.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }
    final regex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$');
    if (!regex.hasMatch(v)) {
      return 'Solo se permiten letras y espacios (sin números)';
    }
    return null;
  }

  /// Validador de Cédula de Nicaragua: 000-000000-0000A
  static String? validateCedula(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) {
      return 'El número de cédula es obligatorio';
    }
    final regex = RegExp(r'^\d{3}-\d{6}-\d{4}[A-Z]$');
    if (!regex.hasMatch(v)) {
      return 'Formato requerido: 000-000000-0000A (14 dígitos + letra)';
    }
    return null;
  }

  /// Validador de Teléfono Principal de Nicaragua: +505 0000 0000
  static String? validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v == '+505' || v == '+505 ') {
      return 'El teléfono principal es obligatorio';
    }
    final digits = v.replaceAll(RegExp(r'\D'), '');
    // 505 + 8 dígitos = 11 dígitos en total
    if (digits.length != 11 && digits.length != 8) {
      return 'Ingrese un número válido de Nicaragua (+505 0000 0000)';
    }
    return null;
  }

  /// Validador de Teléfono Opcional de Emergencia (valida solo si se ingresa texto)
  static String? validateOptionalPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v == '+505' || v == '+505 ') {
      return null; // Es opcional
    }
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 && digits.length != 8) {
      return 'Formato de teléfono inválido (+505 0000 0000)';
    }
    return null;
  }

  /// Validador de Dirección de Domicilio
  static String? validateAddress(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'La dirección de domicilio es obligatoria';
    }
    if (v.length < 5) {
      return 'Ingrese una dirección detallada (mínimo 5 caracteres)';
    }
    return null;
  }
}
