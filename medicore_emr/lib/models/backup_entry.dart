enum BackupDestination {
  database,
  internalStorage,
  both;

  String get displayName {
    switch (this) {
      case BackupDestination.database:
        return 'Base de Datos (Supabase Cloud)';
      case BackupDestination.internalStorage:
        return 'Almacenamiento Interno (Local)';
      case BackupDestination.both:
        return 'Ambos (Nube + Almacenamiento Local)';
    }
  }

  String get shortName {
    switch (this) {
      case BackupDestination.database:
        return 'Nube (Supabase)';
      case BackupDestination.internalStorage:
        return 'Almacenamiento Local';
      case BackupDestination.both:
        return 'Híbrido (Nube + Local)';
    }
  }
}

class BackupIdGenerator {
  static int _counter = 0;
  static String next() => 'bk_${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}

class BackupEntry {
  final String id;
  final String name;
  final DateTime date;
  final String size;
  final int sizeBytes;
  final String status;
  final String type; // 'Manual' or 'Automático'
  final BackupDestination destination;
  final int tablesCount;
  final int recordsCount;
  final double durationSeconds;
  final String? filePath;
  final Map<String, dynamic>? data;
  final String? performedBy;

  const BackupEntry({
    required this.id,
    required this.name,
    required this.date,
    required this.size,
    required this.sizeBytes,
    required this.status,
    required this.type,
    required this.destination,
    required this.tablesCount,
    required this.recordsCount,
    required this.durationSeconds,
    this.filePath,
    this.data,
    this.performedBy,
  });

  String get formattedDate {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$min';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'size': size,
      'size_bytes': sizeBytes,
      'status': status,
      'type': type,
      'destination': destination.name,
      'tables_count': tablesCount,
      'records_count': recordsCount,
      'duration_seconds': durationSeconds,
      'file_path': filePath,
      'performed_by': performedBy,
      if (data != null) 'data': data,
    };
  }

  factory BackupEntry.fromMap(Map<String, dynamic> json) {
    BackupDestination dest = BackupDestination.database;
    final destStr = json['destination']?.toString().toLowerCase() ?? '';
    if (destStr.contains('both') || destStr.contains('hibrid') || destStr.contains('ambos')) {
      dest = BackupDestination.both;
    } else if (destStr.contains('internal') || destStr.contains('local') || destStr.contains('storage')) {
      dest = BackupDestination.internalStorage;
    } else {
      dest = BackupDestination.database;
    }

    final rawDate = json['date'] ?? json['created_at'];
    DateTime parsedDate = DateTime.now();
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    Map<String, dynamic>? parsedData;
    if (json['data'] != null) {
      if (json['data'] is Map) {
        parsedData = Map<String, dynamic>.from(json['data'] as Map);
      }
    }

    return BackupEntry(
      id: json['id']?.toString() ?? BackupIdGenerator.next(),
      name: json['name']?.toString() ?? json['backup_name']?.toString() ?? 'Respaldo del Sistema',
      date: parsedDate,
      size: json['size']?.toString() ?? json['size_formatted']?.toString() ?? '0 KB',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Completado',
      type: json['type']?.toString() ?? 'Manual',
      destination: dest,
      tablesCount: (json['tables_count'] as num?)?.toInt() ?? 0,
      recordsCount: (json['records_count'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      filePath: json['file_path']?.toString(),
      data: parsedData,
      performedBy: json['performed_by']?.toString() ?? 'Administrador',
    );
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
