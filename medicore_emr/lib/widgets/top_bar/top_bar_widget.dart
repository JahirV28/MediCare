import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class TopBarWidget extends StatefulWidget {
  final String? searchHint;
  final bool showSearchBar;
  final ValueChanged<Patient>? onPatientSelected;

  const TopBarWidget({
    super.key,
    this.searchHint = 'Buscar ID / Nombre de Paciente...',
    this.showSearchBar = true,
    this.onPatientSelected,
  });

  @override
  State<TopBarWidget> createState() => _TopBarWidgetState();
}

class _TopBarWidgetState extends State<TopBarWidget> {
  final SupabaseService _api = SupabaseService();
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<Patient> _searchResults = [];
  bool _isSearching = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _searchController.text.trim().isNotEmpty) {
        _search(_searchController.text.trim());
      } else if (!_focusNode.hasFocus) {
        // Retrasar cierre para permitir el tap en los elementos de la lista
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_focusNode.hasFocus) {
            _hideOverlay();
          }
        });
      }
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await _api.getNotifications();
      if (mounted) {
        setState(() => _notifications = notifs);
      }
    } catch (_) {}
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: AppColors.primaryBlue, size: 22),
            const SizedBox(width: 10),
            const Text('Notificaciones Clínicas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
              tooltip: 'Actualizar',
              onPressed: () async {
                Navigator.pop(ctx);
                await _loadNotifications();
                if (mounted) _showNotificationsDialog();
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: _notifications.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 40, color: AppColors.success),
                      SizedBox(height: 10),
                      Text(
                        'Todo al día. No hay alertas ni tareas pendientes.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final n = _notifications[index];
                    final severity = n['severity']?.toString() ?? 'info';
                    Color color = AppColors.primaryBlue;
                    IconData icon = Icons.info_outline;
                    if (severity == 'danger') {
                      color = AppColors.danger;
                      icon = Icons.warning_amber_rounded;
                    } else if (severity == 'warning') {
                      color = AppColors.warning;
                      icon = Icons.priority_high_rounded;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title']?.toString() ?? 'Notificación',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n['message']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog() async {
    final settings = await _api.getClinicSettings();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(12),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_outlined, color: AppColors.primaryBlue, size: 22),
            SizedBox(width: 10),
            Text('Soporte y Mesa de Ayuda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings['clinic_name']?.toString() ?? 'MediCore EMR',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sistema integral de gestión de expedientes clínicos y agenda hospitalaria.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildSupportRow(Icons.phone_outlined, 'Teléfono Soporte', settings['phone']?.toString() ?? '+505 2222 3344'),
              const SizedBox(height: 10),
              _buildSupportRow(Icons.email_outlined, 'Correo Soporte', settings['email']?.toString() ?? 'soporte@medicore.com'),
              const SizedBox(height: 10),
              _buildSupportRow(Icons.schedule_outlined, 'Horario de Atención', settings['schedule_weekday']?.toString() ?? '08:00 — 18:00'),
              const SizedBox(height: 10),
              _buildSupportRow(Icons.location_on_outlined, 'Ubicación', settings['address']?.toString() ?? 'Consultorios Médicos'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _hideOverlay();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _search(clean);
    });
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    _showOrUpdateOverlay();

    try {
      final results = await _api.searchPatients(query, limit: 8);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        _showOrUpdateOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showOrUpdateOverlay();
      }
    }
  }

  void _showOrUpdateOverlay() {
    if (!mounted || !widget.showSearchBar) return;
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectPatient(Patient patient) {
    _hideOverlay();
    _searchController.clear();
    _focusNode.unfocus();
    widget.onPatientSelected?.call(patient);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 420,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 42),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            color: AppColors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: _buildDropdownContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent() {
    if (_isSearching && _searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
            ),
            SizedBox(width: 12),
            Text(
              'Buscando en la base de datos...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.person_search, size: 20, color: AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No se encontraron pacientes para "${_searchController.text.trim()}".',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              const Text(
                'Pacientes encontrados',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${_searchResults.length} resultados en BD',
                style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: _searchResults.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final patient = _searchResults[index];
              return InkWell(
                onTap: () => _selectPatient(patient),
                hoverColor: AppColors.primaryBlue.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                        child: Text(
                          patient.initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.fullName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    patient.patientCode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    patient.phone ?? patient.identityNumber ?? (patient.email ?? 'Sin contacto'),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (patient.hasAlert)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Alerta',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textHint),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Search bar (Oculta cuando showSearchBar es falso)
          if (widget.showSearchBar)
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.search, size: 18, color: AppColors.textHint),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: widget.searchHint,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                            filled: false,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _hideOverlay();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 20),
          // Soporte
          TextButton.icon(
            onPressed: _showSupportDialog,
            icon: const Icon(Icons.headset_mic_outlined, size: 18),
            label: const Text('Soporte', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          // Notificaciones
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22, color: AppColors.textSecondary),
                onPressed: _showNotificationsDialog,
                tooltip: _notifications.isEmpty ? 'Sin notificaciones' : 'Notificaciones (${_notifications.length})',
              ),
              if (_notifications.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // Perfil de Usuario Dinámico
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              final initials = user?.initials ?? 'DR';
              final displayName = user?.fullName ?? 'Usuario';
              final providerId = user?.providerId ?? '';
              final roleName = user?.roleName ?? 'Doctor';

              return PopupMenuButton<String>(
                tooltip: 'Perfil de usuario',
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'logout') {
                    auth.logout();
                    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (providerId.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'ID: $providerId • $roleName',
                              style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (user?.email != null && user!.email.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              user.email,
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                          ),
                        const SizedBox(height: 6),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text(
                          'Cerrar Sesión',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.primaryBlue, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (providerId.isNotEmpty)
                            Text(
                              providerId,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
