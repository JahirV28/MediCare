import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/breadcrumb.dart';

class FinancesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FinancesScreen({super.key, this.onBack});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  String _selectedFilter = 'Este Mes';

  // Mock data
  final List<_TransactionData> _transactions = [
    _TransactionData(date: '18 Ago 2026', patient: 'Ana García', concept: 'Consulta General', amount: 850.00, status: 'Pagado'),
    _TransactionData(date: '18 Ago 2026', patient: 'Carlos López', concept: 'Control', amount: 500.00, status: 'Pagado'),
    _TransactionData(date: '17 Ago 2026', patient: 'María Rodríguez', concept: 'Limpieza Dental', amount: 1200.00, status: 'Pagado'),
    _TransactionData(date: '17 Ago 2026', patient: 'Juan Perez', concept: 'Radiografía', amount: 600.00, status: 'Pendiente'),
    _TransactionData(date: '16 Ago 2026', patient: 'Laura Sánchez', concept: 'Pediatría - Control', amount: 750.00, status: 'Pagado'),
    _TransactionData(date: '15 Ago 2026', patient: 'Pedro Martínez', concept: 'Extracción', amount: 1500.00, status: 'Pagado'),
    _TransactionData(date: '15 Ago 2026', patient: 'Rosa Fernández', concept: 'Consulta General', amount: 850.00, status: 'Cancelado'),
    _TransactionData(date: '14 Ago 2026', patient: 'Miguel Torres', concept: 'Laboratorio', amount: 2300.00, status: 'Pagado'),
    _TransactionData(date: '13 Ago 2026', patient: 'Sofía Herrera', concept: 'Consulta General', amount: 850.00, status: 'Pendiente'),
    _TransactionData(date: '12 Ago 2026', patient: 'Diego Ruiz', concept: 'Ortodoncia', amount: 3500.00, status: 'Pagado'),
  ];

  final List<double> _monthlyIncome = [42500, 38000, 55200, 48700, 61300, 53800];
  final List<String> _monthLabels = ['Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Breadcrumb(
            items: [
              BreadcrumbItem(label: 'Panel', onTap: widget.onBack),
              const BreadcrumbItem(label: 'Finanzas'),
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
                    'Finanzas',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Control de ingresos, gastos y transacciones de la clínica.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildFilterChip('Esta Semana'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Este Mes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Este Año'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Cards
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Ingresos del Mes', '\$53,800', Icons.trending_up, AppColors.success, AppColors.successLight, '+12.4%')),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Gastos del Mes', '\$18,200', Icons.trending_down, AppColors.danger, AppColors.dangerLight, '-3.2%')),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Balance', '\$35,600', Icons.account_balance, AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.1), '+15.1%')),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Citas Cobradas', '127', Icons.receipt_long, AppColors.warning, AppColors.warningLight, '92%')),
            ],
          ),
          const SizedBox(height: 24),

          // Table + Chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transactions table
              Expanded(
                flex: 3,
                child: _buildTransactionsTable(),
              ),
              const SizedBox(width: 20),
              // Monthly chart
              Expanded(
                flex: 2,
                child: _buildMonthlyChart(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isActive = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primaryBlue : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, Color bgColor, String change) {
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  change,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable() {
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
                'Transacciones Recientes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showNewTransactionDialog(),
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Registrar Cobro', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reporte financiero exportado en formato CSV.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exportar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Fecha', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Paciente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Concepto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Monto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Table rows
          ..._transactions.map((tx) {
            Color statusColor;
            Color statusBg;
            switch (tx.status) {
              case 'Pagado':
                statusColor = AppColors.success;
                statusBg = AppColors.successLight;
                break;
              case 'Pendiente':
                statusColor = AppColors.warning;
                statusBg = AppColors.warningLight;
                break;
              default:
                statusColor = AppColors.danger;
                statusBg = AppColors.dangerLight;
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(tx.date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  Expanded(flex: 3, child: Text(tx.patient, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  Expanded(flex: 3, child: Text(tx.concept, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${tx.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        tx.status,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                      ),
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

  Widget _buildMonthlyChart() {
    final maxVal = _monthlyIncome.reduce((a, b) => a > b ? a : b);
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
            'Ingresos Mensuales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text('Últimos 6 meses', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_monthlyIncome.length, (i) {
                final ratio = _monthlyIncome[i] / maxVal;
                final isLast = i == _monthlyIncome.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '\$${(_monthlyIncome[i] / 1000).toStringAsFixed(1)}k',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 150 * ratio,
                          decoration: BoxDecoration(
                            color: isLast ? AppColors.primaryBlue : AppColors.chartBarLight,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _monthLabels[i],
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Promedio Mensual', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                '\$${(_monthlyIncome.reduce((a, b) => a + b) / _monthlyIncome.length / 1000).toStringAsFixed(1)}k',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNewTransactionDialog() {
    final patientCtrl = TextEditingController(text: 'Julio Cortez');
    final conceptCtrl = TextEditingController(text: 'Consulta y Tratamiento');
    final amountCtrl = TextEditingController(text: '150');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: AppColors.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text('Registrar Nuevo Cobro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Paciente',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conceptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Concepto / Servicio',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto (\$) (Ingreso para hoy)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 100.0;
              final pName = patientCtrl.text.trim().isNotEmpty ? patientCtrl.text.trim() : 'Paciente General';
              final concept = conceptCtrl.text.trim().isNotEmpty ? conceptCtrl.text.trim() : 'Consulta Médica';

              setState(() {
                _transactions.insert(
                  0,
                  _TransactionData(
                    date: 'Hoy',
                    patient: pName,
                    concept: concept,
                    amount: amount,
                    status: 'Pagado',
                  ),
                );
              });

              await context.read<DashboardProvider>().recordIncome(amount);

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cobro de \$$amount registrado. Ingreso del día actualizado.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}

class _TransactionData {
  final String date;
  final String patient;
  final String concept;
  final double amount;
  final String status;

  const _TransactionData({
    required this.date,
    required this.patient,
    required this.concept,
    required this.amount,
    required this.status,
  });
}
