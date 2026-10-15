import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/backup_entry.dart';
import '../../providers/auth_provider.dart';
import '../../services/backup_service.dart';
import '../../widgets/common/breadcrumb.dart';

class BackupsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BackupsScreen({super.key, this.onBack});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> with SingleTickerProviderStateMixin {
  final BackupService _backupService = BackupService();

  bool _isLoadingHistory = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  double _backupProgress = 0.0;
  String _backupStepMessage = 'Preparando respaldo...';

  bool _autoBackupEnabled = true;
  String _autoBackupFrequency = 'Diario';

  List<BackupEntry> _backups = [];

  BackupEntry? get _lastSuccessfulBackup {
    try {
      return _backups.firstWhere((b) => b.status == 'Completado');
    } catch (_) {
      return _backups.isNotEmpty ? _backups.first : null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingHistory = true);

    try {
      final settings = await _backupService.getAutoBackupSettings();
      _autoBackupEnabled = settings['enabled'] as bool? ?? true;
      _autoBackupFrequency = settings['frequency'] as String? ?? 'Diario';
    } catch (_) {}

    try {
      final history = await _backupService.getBackupHistory();
      if (mounted) {
        setState(() {
          _backups = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BACKUP CREATION DIALOG & FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showCreateBackupDialog() async {
    BackupDestination selectedDestination = BackupDestination.database;
    final now = DateTime.now();
    final defaultName = 'Respaldo_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final nameController = TextEditingController(text: defaultName);

    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isBackingUp,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crear Respaldo del Sistema',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Seleccione el destino para almacenar la información.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scope info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: AppColors.primaryBlue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Se respaldarán 18 tablas (Pacientes, Citas, Consultas, Recetas, Odontograma, Pediatría, Finanzas, Configuración y Usuarios).',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Destino del Respaldo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),

                      // Destination 1: Database (Supabase Cloud)
                      _buildDestinationCard(
                        destination: BackupDestination.database,
                        currentSelected: selectedDestination,
                        icon: Icons.cloud_done_outlined,
                        title: 'Base de Datos (Supabase Cloud)',
                        subtitle: 'Almacena un snapshot seguro en la nube de Supabase. Recomendado para acceso sincronizado.',
                        badge: 'Nube',
                        onSelect: () => setDialogState(() => selectedDestination = BackupDestination.database),
                      ),
                      const SizedBox(height: 10),

                      // Destination 2: Internal Storage (Local JSON file)
                      _buildDestinationCard(
                        destination: BackupDestination.internalStorage,
                        currentSelected: selectedDestination,
                        icon: Icons.save_alt_outlined,
                        title: 'Almacenamiento Interno (Local)',
                        subtitle: 'Exporta y descarga un archivo .json estructurado en la memoria de este equipo.',
                        badge: 'Archivo Local',
                        onSelect: () => setDialogState(() => selectedDestination = BackupDestination.internalStorage),
                      ),
                      const SizedBox(height: 10),

                      // Destination 3: Both
                      _buildDestinationCard(
                        destination: BackupDestination.both,
                        currentSelected: selectedDestination,
                        icon: Icons.sync_outlined,
                        title: 'Ambos (Nube Supabase + Almacenamiento Local)',
                        subtitle: 'Máxima redundancia: guarda en la base de datos Supabase y descarga una copia física en su equipo.',
                        badge: 'Recomendado',
                        badgeColor: AppColors.success,
                        onSelect: () => setDialogState(() => selectedDestination = BackupDestination.both),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Nombre / Identificador del Respaldo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Ej. Respaldo previo a auditoría',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Comenzar Respaldo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldProceed != true) return;

    // Start executing the backup
    await _executeBackup(
      destination: selectedDestination,
      name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : defaultName,
    );
  }

  Widget _buildDestinationCard({
    required BackupDestination destination,
    required BackupDestination currentSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    Color? badgeColor,
    required VoidCallback onSelect,
  }) {
    final isSelected = destination == currentSelected;
    final bColor = badgeColor ?? AppColors.primaryBlue;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 24, color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeBackup({
    required BackupDestination destination,
    required String name,
  }) async {
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.05;
      _backupStepMessage = 'Conectando con el origen de datos...';
    });

    final auth = context.read<AuthProvider>();
    final userLabel = auth.currentUser?.fullName ?? auth.currentUser?.email ?? 'Administrador';

    try {
      final newBackup = await _backupService.createBackup(
        destination: destination,
        name: name,
        performedBy: userLabel,
        type: 'Manual',
        onProgress: (stepMessage, progress) {
          if (mounted) {
            setState(() {
              _backupStepMessage = stepMessage;
              _backupProgress = progress;
            });
          }
        },
      );

      // Refresh backup list
      final updatedHistory = await _backupService.getBackupHistory();

      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backups = updatedHistory;
        });

        // Show comprehensive success modal
        _showBackupSuccessDialog(newBackup);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar respaldo: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showBackupSuccessDialog(BackupEntry backup) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '¡Respaldo Exitoso!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El respaldo "${backup.name}" fue creado y asegurado satisfactoriamente.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildSuccessDetailRow('Destino:', backup.destination.displayName),
                      const SizedBox(height: 8),
                      _buildSuccessDetailRow('Tamaño del archivo:', backup.size),
                      const SizedBox(height: 8),
                      _buildSuccessDetailRow('Tablas respaldadas:', '${backup.tablesCount} tablas'),
                      const SizedBox(height: 8),
                      _buildSuccessDetailRow('Total de registros:', '${backup.recordsCount} registros'),
                      const SizedBox(height: 8),
                      _buildSuccessDetailRow('Duración:', '${backup.durationSeconds.toStringAsFixed(2)}s'),
                      if (backup.filePath != null) ...[
                        const Divider(height: 16),
                        _buildSuccessDetailRow('Ubicación local:', backup.filePath!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (backup.filePath != null)
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: backup.filePath!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ruta copiada al portapapeles')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar Ruta'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESTORE BACKUP FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _restoreBackup(BackupEntry backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
              SizedBox(width: 12),
              Text('¿Restaurar Respaldo?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Está a punto de restaurar los datos guardados en "${backup.name}" (${backup.formattedDate}).',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Atención: La información actual de las 18 tablas se actualizará con los registros de este respaldo.',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.settings_backup_restore, size: 18),
              label: const Text('Restaurar Ahora'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      final success = await _backupService.restoreBackup(
        backup,
        onProgress: (msg, prog) {
          // progress tracking
        },
      );

      if (mounted) {
        setState(() => _isRestoring = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Base de datos y registros restaurados exitosamente!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadInitialData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron restaurar todos los registros.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DOWNLOAD BACKUP TO DISK
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _downloadBackup(BackupEntry backup) async {
    try {
      final path = await _backupService.downloadBackupToFile(backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null ? 'Respaldo guardado en: $path' : 'Respaldo descargado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar archivo: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESTORE FROM LOCAL FILE / JSON MODAL
  // ══════════════════════════════════════════════════════════════════════════

  void _showRestoreFromManualJsonDialog() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Restaurar desde Archivo Local / JSON', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pegue el contenido JSON del respaldo descargado previamente para restaurar las tablas:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: '{\n  "metadata": {...},\n  "tables": {...}\n}',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = textCtrl.text.trim();
                if (raw.isEmpty) return;
                try {
                  final decoded = jsonDecode(raw) as Map<String, dynamic>;
                  Navigator.pop(ctx);
                  final tempEntry = BackupEntry(
                    id: 'custom_import',
                    name: 'Respaldo Importado',
                    date: DateTime.now(),
                    size: BackupEntry.formatBytes(raw.length),
                    sizeBytes: raw.length,
                    status: 'Completado',
                    type: 'Manual',
                    destination: BackupDestination.internalStorage,
                    tablesCount: (decoded['tables'] as Map?)?.length ?? 18,
                    recordsCount: (decoded['metadata']?['total_records'] as num?)?.toInt() ?? 0,
                    durationSeconds: 1.0,
                    data: decoded,
                  );
                  await _restoreBackup(tempEntry);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('JSON inválido: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Validar y Restaurar'),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ══════════════════════════════════════════════════════════════════════════

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
              const BreadcrumbItem(label: 'Respaldos'),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Respaldos',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestione los respaldos de seguridad de su base de datos.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showRestoreFromManualJsonDialog,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Cargar Respaldo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top section: Status + Config
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last backup status
              Expanded(flex: 3, child: _buildLastBackupCard()),
              const SizedBox(width: 20),
              // Auto backup config
              Expanded(flex: 2, child: _buildAutoBackupConfig()),
            ],
          ),
          const SizedBox(height: 24),

          // Backup history table
          _buildBackupHistory(),
        ],
      ),
    );
  }

  Widget _buildLastBackupCard() {
    final last = _lastSuccessfulBackup;
    final lastDateStr = last != null ? '${last.formattedDate} — ${last.type}' : 'Sin respaldos previos';
    final lastSizeStr = last != null ? last.size : '0 KB';
    final lastTablesStr = last != null ? '${last.tablesCount}' : '18';
    final lastDurationStr = last != null ? '${last.durationSeconds.toStringAsFixed(1)}s' : '0s';

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_done_outlined, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Último Respaldo Exitoso',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastDateStr,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _buildStatPill(Icons.storage_outlined, 'Tamaño', lastSizeStr),
              const SizedBox(width: 16),
              _buildStatPill(Icons.table_chart_outlined, 'Tablas', lastTablesStr),
              const SizedBox(width: 16),
              _buildStatPill(Icons.timer_outlined, 'Duración', lastDurationStr),
            ],
          ),
          const SizedBox(height: 20),

          // Progress or backup button
          if (_isBackingUp)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _backupStepMessage,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_backupProgress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _backupProgress,
                    backgroundColor: AppColors.background,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    minHeight: 8,
                  ),
                ),
              ],
            )
          else if (_isRestoring)
            const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Restaurando base de datos...', style: TextStyle(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateBackupDialog,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Crear Respaldo Ahora'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupConfig() {
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
          const Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Respaldos Automáticos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Habilitar', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              Switch(
                value: _autoBackupEnabled,
                onChanged: (val) {
                  setState(() => _autoBackupEnabled = val);
                  _backupService.saveAutoBackupSettings(_autoBackupEnabled, _autoBackupFrequency);
                },
                activeThumbColor: AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Frequency
          const Text('Frecuencia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _autoBackupFrequency,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: ['Cada 6 horas', 'Diario', 'Semanal']
                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: _autoBackupEnabled
                ? (val) {
                    if (val != null) {
                      setState(() => _autoBackupFrequency = val);
                      _backupService.saveAutoBackupSettings(_autoBackupEnabled, _autoBackupFrequency);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),
          const Text('Hora: 02:00 AM', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Retención: 30 días', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBackupHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial de Respaldos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              IconButton(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                tooltip: 'Actualizar historial',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Fecha y Hora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Tamaño', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Tipo / Destino', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Acciones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
          ),

          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_backups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No hay respaldos registrados todavía.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            ..._backups.map((b) {
              final isFailed = b.status == 'Fallido';

              IconData destIcon;
              switch (b.destination) {
                case BackupDestination.database:
                  destIcon = Icons.cloud_outlined;
                  break;
                case BackupDestination.internalStorage:
                  destIcon = Icons.save_alt_outlined;
                  break;
                case BackupDestination.both:
                  destIcon = Icons.sync_outlined;
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isFailed ? AppColors.dangerLight.withValues(alpha: 0.3) : Colors.transparent,
                  border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (b.name != 'Respaldo del Sistema' && b.name.isNotEmpty)
                            Text(b.name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(b.size, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(destIcon, size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${b.type} (${b.destination.shortName})',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFailed ? AppColors.dangerLight : AppColors.successLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            b.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isFailed ? AppColors.danger : AppColors.success),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          if (!isFailed)
                            InkWell(
                              onTap: () => _restoreBackup(b),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Restaurar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                              ),
                            ),
                          const SizedBox(width: 6),
                          if (!isFailed)
                            InkWell(
                              onTap: () => _downloadBackup(b),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.download_outlined, size: 14, color: AppColors.textSecondary),
                              ),
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
    );
  }
}
