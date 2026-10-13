import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_customer_history_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/settle_salary_dialog.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeIncomeDetailScreen extends StatefulWidget {
  const EmployeeIncomeDetailScreen({
    super.key,
    required this.employee,
    required this.period,
    required this.anchorDate,
  });

  final EmployeeItem employee;
  final FinancePeriod period;
  final DateTime anchorDate;

  @override
  State<EmployeeIncomeDetailScreen> createState() =>
      _EmployeeIncomeDetailScreenState();
}

class _EmployeeIncomeDetailScreenState
    extends State<EmployeeIncomeDetailScreen> {
  late FinancePeriod _period = widget.period;
  late DateTime _anchor = widget.anchorDate;

  EmployeeItem get _employee => widget.employee;

  void _openCustomerHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeCustomerHistoryScreen(employee: _employee),
      ),
    );
  }

  Future<void> _settle(List<EmployeeDayIncome> days) async {
    final result = await showSettleSalaryDialog(
      context: context,
      employeeName: _employee.fullName,
      days: days,
    );
    if (result == null || !mounted) return;
    try {
      await context.read<PayoutsStore>().settleDays(
        employee: _employee,
        days: days,
        amount: result.amount,
        bonusConfirmed: result.bonusConfirmed,
        note: result.note,
      );
      final remaining =
          days.fold<double>(0, (sum, day) => sum + day.dueAmount) -
          result.amount;
      ToastService.success(
        'Paid ${FinanceFormat.money(result.amount)} • Remaining ${FinanceFormat.money(remaining > 0 ? remaining : 0)}',
      );
    } catch (_) {
      ToastService.error('Could not settle. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = FinanceCalculator.norm(_employee.fullName);
    final allBills = context
        .watch<BillingStore>()
        .bills
        .where((b) => FinanceCalculator.norm(b.employeeName) == name)
        .toList(growable: false);
    final expenses = context.watch<ExpensesStore>().items;
    final payouts = context.watch<PayoutsStore>();

    final days = FinanceCalculator.employeeDays(
      employee: _employee,
      bills: allBills,
      expenses: expenses,
      payoutsById: payouts.payoutsById,
      include: (d) => FinanceCalculator.periodContains(d, _anchor, _period),
    );
    final totalEarning = days.fold<double>(0, (s, d) => s + d.earning);
    final totalPaid = days.fold<double>(0, (s, d) => s + d.paidAmount);
    final totalDue = days.fold<double>(0, (s, d) => s + d.dueAmount);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, 'Employee Income'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 760 : double.infinity),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              _ProfileCard(employee: _employee),
              const SizedBox(height: 10),
              FinancePeriodBar(
                period: _period,
                anchor: _anchor,
                onPeriodChanged: (p) => setState(() => _period = p),
                onAnchorChanged: (d) => setState(() => _anchor = d),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FinanceStatCard(
                        title: 'Total Earning',
                        amount: totalEarning,
                        icon: CupertinoIcons.money_dollar_circle,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FinanceStatCard(
                        title: 'Paid',
                        amount: totalPaid,
                        icon: CupertinoIcons.checkmark_circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FinanceStatCard(
                        title: 'Due Amount',
                        amount: totalDue,
                        icon: CupertinoIcons.clock,
                        color: totalDue > 0
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: totalDue > 0 ? () => _settle(days) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    disabledBackgroundColor: const Color(0xFFDADADA),
                    disabledForegroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.checkmark_seal, size: 16),
                  label: Text(
                    totalDue > 0
                        ? 'Settle All  •  ${FinanceFormat.money(totalDue)}'
                        : 'All settled',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _openCustomerHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.person_2, size: 16),
                  label: Text(
                    'Customer History  •  ${allBills.length} bills',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const FinanceSectionTitle('Daily Income'),
              if (days.isEmpty)
                const FinanceEmpty(message: 'No income in this period.')
              else
                ...days.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DayIncomeTile(
                      day: d,
                      onSettle: d.dueAmount > 0 ? () => _settle([d]) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.employee});

  final EmployeeItem employee;

  @override
  Widget build(BuildContext context) {
    final speciality = employee.speciality?.trim();
    final commission = FinanceCalculator.commissionPercent(employee.commission);
    return FinanceCard(
      child: Row(
        children: [
          EmployeeAvatar(employee: employee, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (speciality == null || speciality.isEmpty)
                      ? 'Employee'
                      : speciality,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${commission.toStringAsFixed(0)}% share',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayIncomeTile extends StatelessWidget {
  const _DayIncomeTile({required this.day, required this.onSettle});

  final EmployeeDayIncome day;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  FinanceFormat.dayHeader(day.date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (day.isSettled)
                _Badge(
                  text: 'Settled ${FinanceFormat.time(day.payout!.settledAt)}',
                  color: AppColors.success,
                )
              else if (onSettle != null)
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: onSettle,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Settle',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell('Earning', day.earning, AppColors.textPrimary),
              _cell('Bonus/Tip', day.bonusAmount, AppColors.success),
              _cell('Paid', day.paidAmount, AppColors.success),
              _cell(
                'Due',
                day.dueAmount,
                day.dueAmount > 0 ? AppColors.danger : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              FinanceFormat.money(value),
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
