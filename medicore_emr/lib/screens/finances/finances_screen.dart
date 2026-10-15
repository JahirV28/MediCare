import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/patient.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/breadcrumb.dart';
import '../../widgets/common/patient_autocomplete_field.dart';

class FinancesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FinancesScreen({super.key, this.onBack});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  final SupabaseService _api = SupabaseService();

  // Exchange rate USD -> NIO (Córdobas)
  static const double kExchangeRate = 36.62;

  // Selected filters
  String _selectedFilter = 'Este Mes';
  String _selectedCurrency = 'USD'; // 'USD' or 'NIO'

  // Transactions & Metrics from Supabase
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic> _metrics = {
    'total_income': 0.0,
    'total_expenses': 0.0,
    'balance': 0.0,
    'billed_count': 0,
    'paid_percentage': 100,
  };
  List<Map<String, dynamic>> _monthlySeries = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFinancialData();
  }

  Future<void> _loadAllFinancialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getFinancialTransactions(period: _selectedFilter),
        _api.getFinancialMetrics(period: _selectedFilter),
        _api.getMonthlyIncomeHistory(months: 6),
      ]);

      if (mounted) {
        setState(() {
          _transactions = results[0] as List<Map<String, dynamic>>;
          _metrics = results[1] as Map<String, dynamic>;
          _monthlySeries = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando finanzas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amountInUsd, {bool isK = false}) {
    final isNio = _selectedCurrency == 'NIO';
    final rawVal = isNio ? (amountInUsd * kExchangeRate) : amountInUsd;

    if (isK && rawVal >= 1000) {
      final inK = rawVal / 1000;
      final prefix = isNio ? 'C\$ ' : '\$';
      return '$prefix${inK.toStringAsFixed(1)}k';
    }

    final prefix = isNio ? 'C\$ ' : '\$';
    return '$prefix${_formatNumber(rawVal)}';
  }

  String _formatNumber(double val) {
    final parts = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2).split('.');
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = parts[0].replaceAllMapped(regex, (match) => '${match[1]},');
    return parts.length > 1 ? '$formattedInt.${parts[1]}' : formattedInt;
  }

  @override
  Widget build(BuildContext context) {
    final income = (_metrics['total_income'] as num?)?.toDouble() ?? 0.0;
    final expenses = (_metrics['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final balance = (_metrics['balance'] as num?)?.toDouble() ?? 0.0;
    final billedCount = (_metrics['billed_count'] as num?)?.toInt() ?? 0;
    final paidPercent = (_metrics['paid_percentage'] as num?)?.toInt() ?? 100;

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

          // Header con Filtro de Período y Selector de Moneda
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
                    'Control y registro real de ingresos, egresos y facturación de la clínica.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  // Selector de Moneda (Córdobas / Dólares)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        _buildCurrencyOption('USD', '\$ USD'),
                        _buildCurrencyOption('NIO', 'C\$ NIO (Córdobas)'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Filtros de Período
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

          // Summary Cards conectados a la BD
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Ingresos (${_selectedFilter.toLowerCase()})',
                  _formatMoney(income),
                  Icons.trending_up,
                  AppColors.success,
                  AppColors.successLight,
                  'Real BD',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Gastos (${_selectedFilter.toLowerCase()})',
                  _formatMoney(expenses),
                  Icons.trending_down,
                  AppColors.danger,
                  AppColors.dangerLight,
                  'Egresos',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Balance Neto',
                  _formatMoney(balance),
                  Icons.account_balance,
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withValues(alpha: 0.1),
                  balance >= 0 ? '+ Positivo' : '- Déficit',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Citas y Cobros',
                  billedCount.toString(),
                  Icons.receipt_long,
                  AppColors.warning,
                  AppColors.warningLight,
                  '$paidPercent% Pagado',
                ),
              ),
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

  Widget _buildCurrencyOption(String code, String label) {
    final isSelected = _selectedCurrency == code;
    return InkWell(
      onTap: () => setState(() => _selectedCurrency = code),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isActive = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = label);
        _loadAllFinancialData();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue : AppColors.white,
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, Color bgColor, String tag) {
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
                  tag,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              Row(
                children: [
                  const Text(
                    'Transacciones Recientes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_transactions.length} en BD',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showNewTransactionDialog,
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Registrar Cobro', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadAllFinancialData,
                    icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Recargar transacciones',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                ),
              ),
            )
          else if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 42, color: AppColors.textHint),
                    const SizedBox(height: 10),
                    Text(
                      'No hay transacciones registradas para $_selectedFilter.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Los nuevos cobros registrados aparecerán aquí automáticamente.',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Fecha', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 3, child: Text('Paciente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 3, child: Text('Concepto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('Monto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Table rows
            ..._transactions.map((tx) {
              final status = (tx['status']?.toString() ?? 'Pagado');
              Color statusColor;
              Color statusBg;
              switch (status.toLowerCase()) {
                case 'pagado':
                case 'paid':
                  statusColor = AppColors.success;
                  statusBg = AppColors.successLight;
                  break;
                case 'pendiente':
                case 'pending':
                  statusColor = AppColors.warning;
                  statusBg = AppColors.warningLight;
                  break;
                default:
                  statusColor = AppColors.danger;
                  statusBg = AppColors.dangerLight;
              }

              final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
              final pCode = tx['patient_code']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        tx['date']?.toString() ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['patient']?.toString() ?? 'Paciente General',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (pCode.isNotEmpty)
                            Text(
                              pCode,
                              style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        tx['concept']?.toString() ?? 'Atención Médica',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatMoney(amt),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          status,
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
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    // Calcular máximo para la escala relativa de las barras
    double maxVal = 0.0;
    for (var m in _monthlySeries) {
      final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt > maxVal) maxVal = amt;
    }
    if (maxVal == 0.0) maxVal = 100.0; // Evitar división por cero

    double totalLast6Months = 0.0;
    for (var m in _monthlySeries) {
      totalLast6Months += (m['amount'] as num?)?.toDouble() ?? 0.0;
    }
    final avgMonthly = _monthlySeries.isNotEmpty ? totalLast6Months / _monthlySeries.length : 0.0;

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
                'Ingresos Mensuales',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedCurrency == 'NIO' ? 'En Córdobas (C\$)' : 'En Dólares (\$)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Últimos 6 meses (Datos reales de Supabase)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_monthlySeries.length, (i) {
                final item = _monthlySeries[i];
                final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                final ratio = maxVal > 0 ? (amt / maxVal) : 0.0;
                final isLast = i == _monthlySeries.length - 1;
                final label = item['month_label']?.toString() ?? '';

                // Altura mínima visual de 8px para que los meses sin ventas se vean estéticos
                final barHeight = amt > 0 ? math.max(14.0, 150 * ratio) : 6.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatMoney(amt, isK: true),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isLast
                                ? AppColors.primaryBlue
                                : (amt > 0 ? AppColors.chartBarLight : AppColors.borderLight),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                            color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
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
              const Text('Promedio Mensual Real', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                _formatMoney(avgMonthly),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODAL REGISTRAR COBRO (PACIENTES REALES, MONEDA, CONCEPTO Y MÉTODO DE PAGO)
  // ══════════════════════════════════════════════════════════════════════════

  void _showNewTransactionDialog() {
    Patient? selectedPatient;
    final conceptCtrl = TextEditingController(text: 'Consulta Médica General');
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController(
      text: 'REC-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
    );

    String transactionType = 'Income'; // 'Income' or 'Expense'
    String paymentCurrency = _selectedCurrency; // 'USD' or 'NIO'
    String paymentMethod = 'Cash'; // Cash, Credit Card, Debit Card, Transfer
    String paymentStatus = 'Paid'; // Paid, Pending
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Live conversion preview
          final rawAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          String conversionHelper = '';
          if (rawAmount > 0) {
            if (paymentCurrency == 'NIO') {
              final inUsd = rawAmount / kExchangeRate;
              conversionHelper = '≈ \$${inUsd.toStringAsFixed(2)} USD (Tasa: $kExchangeRate)';
            } else {
              final inNio = rawAmount * kExchangeRate;
              conversionHelper = '≈ C\$ ${_formatNumber(inNio)} Córdobas (Tasa: $kExchangeRate)';
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_card, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Registrar Transacción Financiera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de Transacción (Ingreso / Egreso)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => transactionType = 'Income'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: transactionType == 'Income' ? AppColors.successLight : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: transactionType == 'Income' ? AppColors.success : AppColors.border,
                                  width: transactionType == 'Income' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward, size: 16, color: transactionType == 'Income' ? AppColors.success : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ingreso (Cobro a Paciente)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: transactionType == 'Income' ? AppColors.success : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => transactionType = 'Expense'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: transactionType == 'Expense' ? AppColors.dangerLight : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: transactionType == 'Expense' ? AppColors.danger : AppColors.border,
                                  width: transactionType == 'Expense' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward, size: 16, color: transactionType == 'Expense' ? AppColors.danger : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Gasto / Egreso Clínico',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: transactionType == 'Expense' ? AppColors.danger : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Paciente Autocomplete (Solo obligatorio en Ingresos)
                    if (transactionType == 'Income') ...[
                      PatientAutocompleteField(
                        label: 'Buscar Paciente por Nombre o ID *',
                        hint: 'Escriba las primeras letras del paciente registrado...',
                        onPatientSelected: (patient) {
                          setDialogState(() {
                            selectedPatient = patient;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Concepto / Servicio
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Concepto / Servicio *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: conceptCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Ej. Consulta General, Limpieza Dental, Curación...',
                                  prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nº Recibo / Folio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: invoiceCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.tag, size: 18),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Selector de Moneda y Monto
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Moneda (Dólares o Córdobas)
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Moneda *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: paymentCurrency,
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                items: const [
                                  DropdownMenuItem(value: 'USD', child: Text('\$ USD (Dólares)')),
                                  DropdownMenuItem(value: 'NIO', child: Text('C\$ Córdobas')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => paymentCurrency = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Campo de Monto
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monto en ${paymentCurrency == 'NIO' ? "Córdobas (C\$)" : "Dólares (\$)"} *',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  hintText: paymentCurrency == 'NIO' ? 'Ej. 500, 1500' : 'Ej. 25, 100',
                                  prefixIcon: Icon(paymentCurrency == 'NIO' ? Icons.currency_exchange : Icons.attach_money, size: 18),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              if (conversionHelper.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    conversionHelper,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Método de Pago y Estado
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Método de Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: paymentMethod,
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                items: const [
                                  DropdownMenuItem(value: 'Cash', child: Text('Efectivo')),
                                  DropdownMenuItem(value: 'Debit Card', child: Text('Tarjeta de Débito')),
                                  DropdownMenuItem(value: 'Credit Card', child: Text('Tarjeta de Crédito')),
                                  DropdownMenuItem(value: 'Transfer', child: Text('Transferencia Bancaria')),
                                  DropdownMenuItem(value: 'Insurance', child: Text('Seguro Médico')),
                                ],
                                onChanged: (val) => setDialogState(() => paymentMethod = val ?? 'Cash'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estado de Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: paymentStatus,
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                items: const [
                                  DropdownMenuItem(value: 'Paid', child: Text('Pagado')),
                                  DropdownMenuItem(value: 'Pending', child: Text('Pendiente')),
                                ],
                                onChanged: (val) => setDialogState(() => paymentStatus = val ?? 'Paid'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Notas u Observaciones
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notas / Observaciones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Detalles adicionales de la transacción...',
                            prefixIcon: Icon(Icons.notes, size: 18),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final rawAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        final concept = conceptCtrl.text.trim();

                        if (rawAmt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingrese un monto válido mayor a 0.'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                        if (concept.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingrese el concepto del cobro.'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }

                        // Normalizar siempre el monto base en USD en la base de datos
                        final double amountInUsd = paymentCurrency == 'NIO' ? (rawAmt / kExchangeRate) : rawAmt;
                        final dashProvider = context.read<DashboardProvider>();
                        final messenger = ScaffoldMessenger.of(context);

                        setDialogState(() => isSaving = true);

                        final success = await _api.registerFinancialTransaction(
                          patientId: selectedPatient?.id,
                          concept: concept,
                          amount: amountInUsd,
                          currency: paymentCurrency,
                          paymentMethod: paymentMethod,
                          status: paymentStatus,
                          transactionType: transactionType,
                          invoiceNumber: invoiceCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );

                        if (mounted) {
                          if (success) {
                            dashProvider.refreshSilently();
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            _loadAllFinancialData();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Transacción registrada exitosamente en Supabase: ${_formatMoney(amountInUsd)}.'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Error al registrar la transacción en la base de datos.'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Registrar Transacción'),
              ),
            ],
          );
        },
      ),
    );
  }
}
