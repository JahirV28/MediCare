import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/diagnostic_file.dart';
import '../../providers/clinical_providers.dart';

class DiagnosticFilesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DiagnosticFilesScreen({super.key, this.onBack});

  @override
  State<DiagnosticFilesScreen> createState() => _DiagnosticFilesScreenState();
}

class _DiagnosticFilesScreenState extends State<DiagnosticFilesScreen> {
  int _currentPage = 1;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiagnosticProvider>().loadFiles(84729);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiagnosticProvider>(
      builder: (context, provider, _) {
        final files = provider.files;
        final selectedFile = provider.selectedFile;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'García, Ana - #EXP-84729',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'F. Nac: 12/04/1980 (43 años) • Femenino',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: widget.onBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        child: const Text('VOLVER AL RESUMEN'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _simulateUpload(provider),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('SUBIR ARCHIVO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Two columns: Left Upload + File list, Right Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── LEFT COLUMN: Dropzone, Filters, Thumbnails ───
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // 1. Drag and Drop Zone
                        InkWell(
                          onTap: () => _simulateUpload(provider),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(alpha: 0.5),
                                width: 1.5,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryBlue),
                                const SizedBox(height: 12),
                                const Text(
                                  'Subir Archivos Diagnósticos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Arrastre y suelte archivos PDF, JPG o DICOM aquí, o haga clic para explorar. Tamaño máximo: 50MB.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. Filter Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              // Category dropdown
                              SizedBox(
                                width: 160,
                                child: DropdownButtonFormField<String>(
                                  initialValue: provider.selectedCategory,
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'All Categories', child: Text('Todas las Categorías', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Lab Results', child: Text('Resultados de Laboratorio', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Imaging', child: Text('Imágenes Médicas', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Referrals', child: Text('Interconsultas', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Dermatology', child: Text('Dermatología', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (v) => provider.setCategory(v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Date filter
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(2023, 10, 10),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Filtrando archivos por fecha: ${picked.day}/${picked.month}/${picked.year}'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Filtrar por fecha', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Grid/List icons
                              IconButton(
                                icon: const Icon(Icons.grid_view, size: 20, color: AppColors.primaryBlue),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.view_list, size: 20, color: AppColors.textHint),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. Thumbnails Row / Grid
                        Row(
                          children: files.map((file) {
                            final isSelected = selectedFile?.id == file.id;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: InkWell(
                                  onTap: () => provider.selectFile(file),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryBlue : AppColors.border,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Icon or thumbnail image
                                        Container(
                                          height: 80,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _iconForCategory(file.category),
                                            size: 36,
                                            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                file.fileName.split('.').first,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(Icons.more_vert, size: 16, color: AppColors.textHint),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Oct ${file.uploadDate.day}, 2023',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // ─── RIGHT COLUMN: Diagnostic Document Preview ───
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top bar with document name and zoom icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vista previa: ${selectedFile?.fileName ?? "Blood_Panel_Q3.pdf"}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, size: 20, color: AppColors.textSecondary),
                                    onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.8, 1.5)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_out, size: 20, color: AppColors.textSecondary),
                                    onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.8, 1.5)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Document Canvas Area
                          Container(
                            height: 380,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282C34),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Laboratory Results Document Simulation
                                Transform.scale(
                                  scale: _zoomLevel,
                                  child: Container(
                                    width: 320,
                                    height: 340,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              color: AppColors.primaryBlue,
                                              child: const Icon(Icons.local_hospital, size: 14, color: AppColors.white),
                                            ),
                                            const SizedBox(width: 8),
                                            const Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('HOSPITAL GENERAL CLÍNICO • LABORATORIO CENTRAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
                                                Text('PACIENTE: GARCÍA, ANA • EXP-84729', style: TextStyle(fontSize: 7, color: AppColors.textSecondary)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        const Text('PANEL METABÓLICO COMPLETO (SANGRE)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        _docRow('GLUCOSA', '98 mg/dL', '70 - 99', 'NORMAL'),
                                        _docRow('NITRÓGENO UREICO (BUN)', '14 mg/dL', '7 - 20', 'NORMAL'),
                                        _docRow('CREATININA', '0.9 mg/dL', '0.6 - 1.2', 'NORMAL'),
                                        _docRow('SODIO', '139 mmol/L', '135 - 145', 'NORMAL'),
                                        _docRow('POTASIO', '4.2 mmol/L', '3.5 - 5.0', 'NORMAL'),
                                        _docRow('CLORURO', '101 mmol/L', '96 - 106', 'NORMAL'),
                                        _docRow('CALCIO SÉRICO', '9.4 mg/dL', '8.5 - 10.2', 'NORMAL'),
                                        const Spacer(),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('Validado por: Dra. M. Lynch, Patóloga Clínica • Página 1/3', style: TextStyle(fontSize: 7, color: AppColors.textHint)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Bottom Pagination Pill
                                Positioned(
                                  bottom: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.contrast, size: 16, color: AppColors.white),
                                          onPressed: () {},
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.fullscreen, size: 18, color: AppColors.white),
                                          onPressed: () {},
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () => setState(() => _currentPage = _currentPage == 3 ? 1 : _currentPage + 1),
                                          child: Text(
                                            'Página $_currentPage/3',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Metadata footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fecha de Subida', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedFile != null
                                        ? '${selectedFile.uploadDate.day} Oct, ${selectedFile.uploadDate.year} ${selectedFile.uploadDate.hour}:${selectedFile.uploadDate.minute.toString().padLeft(2, '0')}'
                                        : '10 Oct, 2023 14:32',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Subido Por', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedFile?.uploadedBy != null && selectedFile!.uploadedBy.contains('Nurse')
                                        ? selectedFile.uploadedBy.replaceAll('Nurse', 'Enfra.')
                                        : (selectedFile?.uploadedBy ?? 'Enfra. Adams'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Categoría', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedFile?.category ?? 'Lab Results',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Actions buttons: DOWNLOAD and ATTACH TO NOTE
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Descargando archivo diagnóstico...')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                  child: const Text('DESCARGAR'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Archivo adjuntado a la nota médica actual.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('ADJUNTAR A NOTA'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _docRow(String test, String result, String ref, String flag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(test, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600)),
          Text(result, style: const TextStyle(fontSize: 7)),
          Text(ref, style: const TextStyle(fontSize: 7, color: AppColors.textHint)),
          Text(flag, style: const TextStyle(fontSize: 7, color: AppColors.success, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Imaging':
        return Icons.medical_services_outlined;
      case 'Lab Results':
        return Icons.biotech_outlined;
      case 'Referrals':
        return Icons.description_outlined;
      case 'Dermatology':
        return Icons.photo_size_select_actual_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  void _simulateUpload(DiagnosticProvider provider) {
    final newFile = DiagnosticFile(
      patientId: 84729,
      fileName: 'Electrocardiogram_ECG.pdf',
      category: 'Imaging',
      uploadDate: DateTime.now(),
      uploadedBy: 'Dr. Smith',
      fileUrl: 'https://example.com/files/ecg.pdf',
      fileSize: '3.2 MB',
      totalPages: 1,
    );
    provider.uploadFile(newFile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivo subido con éxito.'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
