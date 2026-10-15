import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicore_emr/models/backup_entry.dart';
import 'package:medicore_emr/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );
  });

  test('BackupEntry serialization and formatting', () {
    final entry = BackupEntry(
      id: 'bk_1',
      name: 'Respaldo de Prueba',
      date: DateTime(2026, 10, 14, 15, 30),
      size: '245.3 KB',
      sizeBytes: 251187,
      status: 'Completado',
      type: 'Manual',
      destination: BackupDestination.both,
      tablesCount: 18,
      recordsCount: 75,
      durationSeconds: 1.45,
      performedBy: 'Dr. Smith',
    );

    final map = entry.toMap();
    expect(map['name'], equals('Respaldo de Prueba'));
    expect(map['destination'], equals('both'));
    expect(entry.formattedDate, contains('14'));
    expect(entry.formattedDate, contains('15:30'));

    final restored = BackupEntry.fromMap(map);
    expect(restored.name, equals('Respaldo de Prueba'));
    expect(restored.destination, equals(BackupDestination.both));
    expect(restored.tablesCount, equals(18));
  });

  test('BackupService createBackup produces valid entry', () async {
    final service = BackupService();
    final backup = await service.createBackup(
      destination: BackupDestination.database,
      name: 'Test Backup Unit',
      performedBy: 'Test Runner',
    );

    expect(backup.name, equals('Test Backup Unit'));
    expect(backup.status, equals('Completado'));
    expect(backup.tablesCount, greaterThan(0));

    final history = await service.getBackupHistory();
    expect(history.any((b) => b.name == 'Test Backup Unit'), isTrue);
  });
}
