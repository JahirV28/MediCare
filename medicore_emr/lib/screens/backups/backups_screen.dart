import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/breadcrumb.dart';

class BackupsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BackupsScreen({super.key, this.onBack});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> with SingleTickerProviderStateMixin {
  bool _isBackingUp = false;
  double _backupProgress = 0;
  bool _autoBackupEnabled = true;
  String _autoBackupFrequency = 'Diario';

  final List<_BackupEntry> _backups = [
    _BackupEntry(date: '18 Ago 2026, 02:00', size: '245.3 MB', status: 'Completado', type: 'Automático'),
    _BackupEntry(date: '17 Ago 2026, 02:00', size: '243.8 MB', status: 'Completado', type: 'Automático'),
    _BackupEntry(date: '16 Ago 2026, 14:32', size: '242.1 MB', status: 'Completado', type: 'Manual'),
    _BackupEntry(date: '16 Ago 2026, 02:00', size: '241.5 MB', status: 'Completado', type: 'Automático'),
    _BackupEntry(date: '15 Ago 2026, 02:00', size: '240.2 MB', status: 'Completado', type: 'Automático'),
    _BackupEntry(date: '14 Ago 2026, 02:00', size: '238.9 MB', status: 'Fallido', type: 'Automático'),
    _BackupEntry(date: '13 Ago 2026, 02:00', size: '237.6 MB', status: 'Completado', type: 'Automático'),
    _BackupEntry(date: '10 Ago 2026, 16:45', size: '235.1 MB', status: 'Completado', type: 'Manual'),
  ];

  Future<void> _startBackup() async {
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0;
    });

    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() => _backupProgress = i / 100.0);
    }

    setState(() {
      _isBackingUp = false;
      _backups.insert(0, _BackupEntry(
        date: '${DateTime.now().day} Ago ${DateTime.now().year}, ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        size: '246.1 MB',
        status: 'Completado',
        type: 'Manual',
      ));
    });
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
              const BreadcrumbItem(label: 'Respaldos'),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Respaldos',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestione los respaldos de seguridad de su base de datos.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Último Respaldo Exitoso',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '18 Ago 2026, 02:00 AM — Automático',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
              _buildStatPill(Icons.storage_outlined, 'Tamaño', '245.3 MB'),
              const SizedBox(width: 16),
              _buildStatPill(Icons.table_chart_outlined, 'Tablas', '24'),
              const SizedBox(width: 16),
              _buildStatPill(Icons.timer_outlined, 'Duración', '1m 42s'),
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
                    const Text('Creando respaldo...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                    Text('${(_backupProgress * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
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
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startBackup,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Crear Respaldo Ahora'),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
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
                onChanged: (val) => setState(() => _autoBackupEnabled = val),
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
            items: ['Cada 6 horas', 'Diario', 'Semanal'].map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: _autoBackupEnabled ? (val) => setState(() => _autoBackupFrequency = val ?? 'Diario') : null,
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
          const Text(
            'Historial de Respaldos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
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
                Expanded(flex: 2, child: Text('Tipo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Acciones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
          ),

          ..._backups.map((b) {
            final isFailed = b.status == 'Fallido';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isFailed ? AppColors.dangerLight.withValues(alpha: 0.3) : Colors.transparent,
                border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(b.date, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                  Expanded(flex: 2, child: Text(b.size, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(
                          b.type == 'Manual' ? Icons.person_outline : Icons.schedule,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(b.type, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
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
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (!isFailed)
                          InkWell(
                            onTap: () {},
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
                            onTap: () {},
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

class _BackupEntry {
  final String date;
  final String size;
  final String status;
  final String type;

  const _BackupEntry({
    required this.date,
    required this.size,
    required this.status,
    required this.type,
  });
}
