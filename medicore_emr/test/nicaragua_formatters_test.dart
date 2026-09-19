import 'package:flutter_test/flutter_test.dart';
import 'package:medicore_emr/core/utils/nicaragua_formatters.dart';
import 'package:medicore_emr/models/patient.dart';
import 'package:medicore_emr/models/emergency_contact.dart';
import 'package:medicore_emr/services/mock_api_service.dart';

void main() {
  group('Nicaragua Formatters & Validators Tests', () {
    test('Name validation rejects numbers and accepts valid names', () {
      expect(NicaraguaValidators.validateFullName(''), isNotNull);
      expect(NicaraguaValidators.validateFullName('123'), isNotNull);
      expect(NicaraguaValidators.validateFullName('equisde111111'), isNotNull);
      expect(NicaraguaValidators.validateFullName('Juan123'), isNotNull);
      expect(NicaraguaValidators.validateFullName('Ana María Silva'), isNull);
      expect(NicaraguaValidators.validateFullName('José Ramón Núñez'), isNull);
    });

    test('Nicaraguan Cedula validation and formatting', () {
      // Formato: 000-000000-0000A
      expect(NicaraguaValidators.validateCedula(''), isNotNull);
      expect(NicaraguaValidators.validateCedula('15651456464564'), isNotNull);
      expect(NicaraguaValidators.validateCedula('001-280590-0004'), isNotNull);
      expect(NicaraguaValidators.validateCedula('001-280590-00041'), isNotNull);
      expect(NicaraguaValidators.validateCedula('001-280590-0004X'), isNull);
      expect(NicaraguaValidators.validateCedula('281-010190-1002Y'), isNull);
    });

    test('Nicaraguan Phone validation and formatting', () {
      expect(NicaraguaValidators.validatePhone(''), isNotNull);
      expect(NicaraguaValidators.validatePhone('+505 '), isNotNull);
      expect(NicaraguaValidators.validatePhone('12345'), isNotNull);
      expect(NicaraguaValidators.validatePhone('+505 8888 1234'), isNull);
      expect(NicaraguaValidators.validatePhone('+505 2222 3333'), isNull);
    });

    test('Optional Phone Validator only validates if text is provided', () {
      expect(NicaraguaValidators.validateOptionalPhone(''), isNull);
      expect(NicaraguaValidators.validateOptionalPhone(null), isNull);
      expect(NicaraguaValidators.validateOptionalPhone('+505 '), isNull);
      expect(NicaraguaValidators.validateOptionalPhone('123'), isNotNull);
      expect(NicaraguaValidators.validateOptionalPhone('+505 8765 4321'), isNull);
    });

    test('Address validation requires detailed address', () {
      expect(NicaraguaValidators.validateAddress(''), isNotNull);
      expect(NicaraguaValidators.validateAddress('abc'), isNotNull);
      expect(NicaraguaValidators.validateAddress('Colonia Los Robles, Casa 45'), isNull);
    });
  });

  group('MockApiService Dynamic Data & Patient Creation Tests', () {
    test('Creating a new patient dynamically increments active count and updates stats', () async {
      final api = MockApiService();

      final initialStats = await api.getDashboardStats();
      final initialCount = initialStats['active_patients'] as int;

      final newPatient = Patient(
        patientCode: 'PT-TEST-001',
        fullName: 'Carlos Alberto Martínez',
        identityNumber: '001-101090-0001A',
        birthDate: DateTime(1990, 10, 10),
        gender: 'Masculino',
        phone: '+505 8888 9999',
        address: 'Managua, Residencial Las Colinas',
        isActive: true,
      );

      final emergency = EmergencyContact(
        contactName: 'Lucía Martínez',
        relationship: 'Esposa',
        phone: '+505 8777 6666',
      );

      final created = await api.createPatient(newPatient, emergencyContact: emergency);
      expect(created, isTrue);

      final updatedStats = await api.getDashboardStats();
      final updatedCount = updatedStats['active_patients'] as int;
      expect(updatedCount, equals(initialCount + 1));

      final patients = await api.getPatients(search: 'Carlos Alberto Martínez');
      expect(patients.isNotEmpty, isTrue);
      expect(patients.first.fullName, equals('Carlos Alberto Martínez'));
      expect(patients.first.identityNumber, equals('001-101090-0001A'));
    });
  });
}
