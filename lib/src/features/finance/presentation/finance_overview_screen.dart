import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/storage/hive_boxes.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_income_detail_screen.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class FinanceOverviewScreen extends StatefulWidget {
  const FinanceOverviewScreen({super.key});

  @override
  State<FinanceOverviewScreen> createState() => _FinanceOverviewScreenState();
}

class _FinanceOverviewScreenState extends State<FinanceOverviewScreen> {
  DateTime _selectedDate = DateTime.now();
  FinancePeriod _period = FinancePeriod.daily;

  @override
  Widget build(BuildContext context) {
    final bills = context.watch<BillingStore>().bills;
    final expenses = context.watch<ExpensesStore>().items;
    final employees = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .toList(growable: false);

    final periodRevenue = bills
        .where((b) => _isInSelectedPeriod(b.createdAt))
        .fold<double>(0, (sum, b) => sum + b.grandTotal);
    final periodExpenses = expenses
        .where((e) => _isInSelectedPeriod(e.date))
        .fold<double>(0, (sum, e) => sum + e.amount);
    final periodProfit = periodRevenue - periodExpenses;
    final periodTransactionCount = bills
        .where((b) => _isInSelectedPeriod(b.createdAt))
        .length;
    final employeeRows = _buildEmployeeRows(
      _selectedDate,
      _period,
      employees,
      bills,
    );
    final isSelectedToday = _isSameDate(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            dateText: _periodDateLabel(),
            onDateTap: _pickDate,
            onResetTap: _resetToToday,
            showReset: !isSelectedToday,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              children: [
                _periodFilterRow(),
                const SizedBox(height: 8),
                _todaySaleCard(
                  amount: periodRevenue,
                  title: _periodCardTitle(),
                  subtitle: '$periodTransactionCount transactions',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.financeSales);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _miniStatCard(
                        title: 'Profit',
                        amount: periodProfit,
                        icon: CupertinoIcons.arrow_up_right,
                        amountColor: AppColors.success,
                        iconColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStatCard(
                        title: 'Expenses',
                        amount: periodExpenses,
                        icon: CupertinoIcons.arrow_down_right,
                        amountColor: AppColors.danger,
                        iconColor: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    'Employee Income',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (employeeRows.isEmpty)
                  _emptyStateCard()
                else
                  ...employeeRows.map(
                    (row) => _employeeIncomeTile(context, row),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _resetToToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static List<_EmployeeIncomeRow> _buildEmployeeRows(
    DateTime now,
    FinancePeriod period,
    List<EmployeeItem> employees,
    List<Bill> bills,
  ) {
    final earningsByEmployee = <String, double>{};
    for (final bill in bills) {
      if (!_periodContains(bill.createdAt, now, period)) continue;
      earningsByEmployee.update(
        _norm(bill.employeeName),
        (existing) => existing + bill.grandTotal,
        ifAbsent: () => bill.grandTotal,
      );
    }

    final rows = employees
        .map((employee) {
          final sales = earningsByEmployee[_norm(employee.fullName)] ?? 0;
          final commissionPercent = _commissionPercent(employee.commission);
          final earning = (sales * commissionPercent) / 100;
          return _EmployeeIncomeRow(employee: employee, todayEarning: earning);
        })
        .toList(growable: false);

    rows.sort((a, b) => b.todayEarning.compareTo(a.todayEarning));
    return rows;
  }

  static double _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final normalized = value.replaceAll(',', '').replaceAll('%', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  static double _commissionPercent(String? value) {
    if (value == null || value.trim().isEmpty) return 100;
    final parsed = _toDouble(value);
    return parsed <= 0 ? 100 : parsed;
  }

  static String _norm(String value) {
    return value.trim().toLowerCase();
  }

  static double _netDueForEmployee({
    required EmployeeItem employee,
    required List<Bill> bills,
    required List<dynamic> expenses,
    required DateTime anchor,
    required FinancePeriod period,
    required Box<Map> payoutBox,
    required double earningEstimate,
  }) {
    final employeeName = _norm(employee.fullName);
    final commissionPercent = _commissionPercent(employee.commission);

    final salesByDay = <DateTime, double>{};
    for (final bill in bills) {
      if (_norm(bill.employeeName) != employeeName) continue;
      if (!_periodContains(bill.createdAt, anchor, period)) continue;
      final day = DateTime(
        bill.createdAt.year,
        bill.createdAt.month,
        bill.createdAt.day,
      );
      salesByDay.update(
        day,
        (v) => v + bill.grandTotal,
        ifAbsent: () => bill.grandTotal,
      );
    }

    final expenseByDay = <DateTime, double>{};
    for (final e in expenses) {
      final emp = (e.employeeName as String?) ?? '';
      if (_norm(emp) != employeeName) continue;
      final status = (e.status as String?) ?? '';
      if (status.trim().toLowerCase() != 'unpaid') continue;
      final date = e.date as DateTime;
      if (!_periodContains(date, anchor, period)) continue;
      final day = DateTime(date.year, date.month, date.day);
      final amount = (e.amount as double?) ?? 0.0;
      expenseByDay.update(day, (v) => v + amount, ifAbsent: () => amount);
    }

    final days = <DateTime>{
      ...salesByDay.keys,
      ...expenseByDay.keys,
    }.toList(growable: false);
    if (days.isEmpty) {
      // Fallback to old number if there were no day groups.
      final safe = earningEstimate < 0 ? 0.0 : earningEstimate;
      return safe;
    }

    double totalDue = 0.0;
    for (final day in days) {
      final sales = salesByDay[day] ?? 0.0;
      final earning = (sales * commissionPercent) / 100;
      final cut = expenseByDay[day] ?? 0.0;
      final net = earning - cut;
      final due = net < 0 ? 0.0 : net;
      final payoutKey =
          'payout:${employee.id}:day:${DateTime(day.year, day.month, day.day).toIso8601String()}';
      final isSettled = payoutBox.get(payoutKey) != null;
      if (!isSettled) {
        totalDue += due;
      }
    }
    return totalDue < 0 ? 0.0 : totalDue;
  }

  bool _isInSelectedPeriod(DateTime date) {
    return _periodContains(date, _selectedDate, _period);
  }

  static bool _periodContains(
    DateTime date,
    DateTime anchor,
    FinancePeriod period,
  ) {
    switch (period) {
      case FinancePeriod.daily:
        return _isSameDate(date, anchor);
      case FinancePeriod.weekly:
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        final target = DateTime(date.year, date.month, date.day);
        return !target.isBefore(start) && !target.isAfter(end);
      case FinancePeriod.monthly:
        return date.year == anchor.year && date.month == anchor.month;
    }
  }

  String _periodCardTitle() {
    switch (_period) {
      case FinancePeriod.daily:
        return 'TODAY SALE';
      case FinancePeriod.weekly:
        return 'WEEKLY SALE';
      case FinancePeriod.monthly:
        return 'MONTHLY SALE';
    }
  }

  String _periodDateLabel() {
    switch (_period) {
      case FinancePeriod.daily:
        return _formatDate(_selectedDate);
      case FinancePeriod.weekly:
        final start = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ).subtract(Duration(days: _selectedDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${_formatDate(start)} - ${_formatDate(end)}';
      case FinancePeriod.monthly:
        const months = <String>[
          'JANUARY',
          'FEBRUARY',
          'MARCH',
          'APRIL',
          'MAY',
          'JUNE',
          'JULY',
          'AUGUST',
          'SEPTEMBER',
          'OCTOBER',
          'NOVEMBER',
          'DECEMBER',
        ];
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    }
  }

  Widget _periodFilterRow() {
    return Row(
      children: [
        _periodChip(FinancePeriod.daily, 'Daily'),
        const SizedBox(width: 8),
        _periodChip(FinancePeriod.weekly, 'Weekly'),
        const SizedBox(width: 8),
        _periodChip(FinancePeriod.monthly, 'Monthly'),
      ],
    );
  }

  Widget _periodChip(FinancePeriod value, String label) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatCurrency(double value) {
    final absolute = value.abs().toStringAsFixed(1);
    final parts = absolute.split('.');
    final whole = parts.first;
    final fraction = parts.last;

    final withCommas = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    final sign = value < 0 ? '-' : '';
    return 'Rs.$sign$withCommas.$fraction';
  }

  Widget _todaySaleCard({
    required double amount,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.money_dollar_circle,
                  color: AppColors.success,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatCurrency(amount),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStatCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color amountColor,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 120,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatCurrency(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _employeeIncomeTile(BuildContext context, _EmployeeIncomeRow row) {
    final expenses = context.watch<ExpensesStore>().items;
    final payoutBox = Hive.box<Map>(HiveBoxes.employeePayouts);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeeIncomeDetailScreen(
                  employee: row.employee,
                  period: _period,
                  anchorDate: _selectedDate,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                _EmployeeAvatar(employeeId: row.employee.id),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employee.speciality?.trim().isNotEmpty == true
                            ? row.employee.speciality!
                            : 'General Specialist',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.employee.fullName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: payoutBox.listenable(),
                      builder: (context, _, __) {
                        final due = _netDueForEmployee(
                          employee: row.employee,
                          bills: context.read<BillingStore>().bills,
                          expenses: expenses,
                          anchor: _selectedDate,
                          period: _period,
                          payoutBox: payoutBox,
                          earningEstimate: row.todayEarning,
                        );
                        final isSettled = due <= 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isSettled ? 'Settled' : 'Net Due',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(due),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'No employee data available.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dateText,
    required this.onDateTap,
    required this.onResetTap,
    required this.showReset,
  });

  final String dateText;
  final VoidCallback onDateTap;
  final VoidCallback onResetTap;
  final bool showReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                CupertinoIcons.back,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDateTap,
                  child: Container(
                    height: 44,
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_down,
                            color: AppColors.primary,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showReset)
              TextButton(
                onPressed: onResetTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Today'),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _EmployeeIncomeRow {
  const _EmployeeIncomeRow({
    required this.employee,
    required this.todayEarning,
  });

  final EmployeeItem employee;
  final double todayEarning;
}

// (migrated to FinancePeriod in domain layer)

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final useAsset = employeeId.hashCode.isEven;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: useAsset
          ? Image.asset(
              'assets/placeholder.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(CupertinoIcons.person_fill, size: 20),
            )
          : const Icon(CupertinoIcons.person_fill, size: 20),
    );
  }
}
