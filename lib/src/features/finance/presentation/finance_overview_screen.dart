import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_income_detail_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class FinanceOverviewScreen extends StatefulWidget {
  const FinanceOverviewScreen({super.key});

  @override
  State<FinanceOverviewScreen> createState() => _FinanceOverviewScreenState();
}

class _FinanceOverviewScreenState extends State<FinanceOverviewScreen> {
  DateTime _selectedDate = DateTime.now();
  FinancePeriod _period = FinancePeriod.daily;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _open(String route) {
    Navigator.of(context).pushNamed(
      route,
      arguments: FinanceRouteArgs(anchor: _selectedDate, period: _period),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bills = context.select<BillingStore, List<Bill>>(
      (store) => store.bills,
    );
    final expenses = context.select<ExpensesStore, List<ExpenseItem>>(
      (store) => store.items,
    );
    final payouts = context.select<PayoutsStore, List<SalaryPayout>>(
      (store) => store.payouts,
    );
    final payoutsById = context.select<PayoutsStore, Map<String, SalaryPayout>>(
      (store) => store.payoutsById,
    );
    final employees = context
        .select<EmployeesStore, List<EmployeeItem>>((store) => store.employees)
        .where((e) => e.isActive)
        .toList(growable: false);

    final totals = FinanceCalculator.totals(
      bills: bills,
      expenses: expenses,
      payouts: payouts,
      anchor: _selectedDate,
      period: _period,
    );

    bool include(DateTime d) =>
        FinanceCalculator.periodContains(d, _selectedDate, _period);
    final rows =
        employees
            .map((employee) {
              final days = FinanceCalculator.employeeDays(
                employee: employee,
                bills: bills,
                expenses: expenses,
                payoutsById: payoutsById,
                include: include,
              );
              return _EmployeeRow(
                employee: employee,
                earning: days.fold<double>(0, (s, d) => s + d.earning),
                due: days.fold<double>(0, (s, d) => s + d.dueAmount),
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.earning.compareTo(a.earning));

    final isToday =
        FinanceCalculator.dayOf(_selectedDate) ==
        FinanceCalculator.dayOf(DateTime.now());
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    final saleCard = _SaleCard(
      title: '${FinanceFormat.periodWord(_period).toUpperCase()} SALE',
      amount: totals.sales,
      subtitle: '${totals.billCount} bills',
      onTap: () => _open(AppRoutes.financeSales),
    );
    final statCards = <Widget>[
      Expanded(
        child: FinanceStatCard(
          title: 'Profit',
          amount: totals.profit,
          icon: CupertinoIcons.arrow_up_right,
          color: totals.profit < 0 ? AppColors.danger : AppColors.success,
          onTap: () => _open(AppRoutes.financeProfit),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FinanceStatCard(
          title: 'Expenses',
          amount: totals.expenses,
          icon: CupertinoIcons.arrow_down_right,
          color: AppColors.danger,
          onTap: () => _open(AppRoutes.financeExpenses),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FinanceStatCard(
          title: 'Salaries',
          amount: totals.salaries,
          icon: CupertinoIcons.person_2,
          color: AppColors.textPrimary,
          onTap: () => _open(AppRoutes.financeSalaries),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            dateText: FinanceFormat.periodLabel(_selectedDate, _period),
            onDateTap: _pickDate,
            onResetTap: () => setState(() => _selectedDate = DateTime.now()),
            showReset: !isToday,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: tablet ? 820 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  children: [
                    Row(
                      children: [
                        for (final entry in const {
                          FinancePeriod.daily: 'Daily',
                          FinancePeriod.weekly: 'Weekly',
                          FinancePeriod.monthly: 'Monthly',
                        }.entries) ...[
                          Expanded(
                            child: FinanceChip(
                              label: entry.value,
                              selected: _period == entry.key,
                              onTap: () => setState(() => _period = entry.key),
                            ),
                          ),
                          if (entry.key != FinancePeriod.monthly)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (tablet)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: saleCard),
                            const SizedBox(width: 8),
                            ...statCards,
                          ],
                        ),
                      )
                    else ...[
                      saleCard,
                      const SizedBox(height: 8),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: statCards,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const FinanceSectionTitle('Employee Income'),
                    if (rows.isEmpty)
                      const FinanceEmpty(message: 'No employees added yet.')
                    else
                      ...rows.map(
                        (row) => _EmployeeTile(
                          row: row,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EmployeeIncomeDetailScreen(
                                employee: row.employee,
                                period: _period,
                                anchorDate: _selectedDate,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final double amount;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.money_dollar_circle,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  FinanceFormat.money(amount),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _EmployeeRow {
  const _EmployeeRow({
    required this.employee,
    required this.earning,
    required this.due,
  });

  final EmployeeItem employee;
  final double earning;
  final double due;
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.row, required this.onTap});

  final _EmployeeRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settled = row.due <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FinanceCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        child: Row(
          children: [
            EmployeeAvatar(employee: row.employee, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.employee.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Earning ${FinanceFormat.money(row.earning)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  settled ? 'Settled' : 'Due',
                  style: TextStyle(
                    color: settled
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  FinanceFormat.money(row.due),
                  style: TextStyle(
                    color: settled ? AppColors.textPrimary : AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textSecondary,
              size: 13,
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
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
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onDateTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          CupertinoIcons.chevron_down,
                          color: AppColors.textPrimary,
                          size: 13,
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
                child: const Text(
                  'Today',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
