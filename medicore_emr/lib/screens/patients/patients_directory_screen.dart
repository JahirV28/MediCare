import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/tables/patients_directory_table.dart';

class PatientsDirectoryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToNewPatient;
  final VoidCallback? onNavigateToDetail;

  const PatientsDirectoryScreen({
    super.key,
    this.onNavigateToNewPatient,
    this.onNavigateToDetail,
  });

  @override
  State<PatientsDirectoryScreen> createState() => _PatientsDirectoryScreenState();
}

class _PatientsDirectoryScreenState extends State<PatientsDirectoryScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().loadPatients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.patients.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              Breadcrumb(
                items: [
                  BreadcrumbItem(label: 'Inicio', onTap: () {}),
                  const BreadcrumbItem(label: 'Pacientes'),
                ],
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Directorio de Pacientes',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gestión integral de expedientes médicos y contactos.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onNavigateToNewPatient,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Paciente'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search and filters
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Nombre, ID o Teléfono...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (value) {
                          provider.loadPatients(search: value, statusFilter: _statusFilter);
                        },
                        onSubmitted: (value) {
                          provider.loadPatients(search: value, statusFilter: _statusFilter);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Estado: Todos')),
                          DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                          DropdownMenuItem(value: 'Inactivo', child: Text('Inactivo')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _statusFilter = v);
                            provider.loadPatients(search: _searchController.text, statusFilter: v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Filtros'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Table
              PatientsDirectoryTable(
                patients: provider.patients,
                totalPatients: provider.totalPatients,
                currentPage: provider.currentPage,
                onPageChanged: (page) => provider.setPage(page),
                onPatientTap: (patient) {
                  provider.selectPatient(patient);
                  widget.onNavigateToDetail?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
