import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/settle_salary_dialog.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

enum _BillRange { today, week, month, custom, all }

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

  _BillRange _billRange = _BillRange.month;
  DateTimeRange? _customRange;
  String _payment = 'All';

  EmployeeItem get _employee => widget.employee;

  bool _billInRange(DateTime date) {
    final now = DateTime.now();
    switch (_billRange) {
      case _BillRange.today:
        return FinanceCalculator.periodContains(date, now, FinancePeriod.daily);
      case _BillRange.week:
        return FinanceCalculator.periodContains(
          date,
          now,
          FinancePeriod.weekly,
        );
      case _BillRange.month:
        return FinanceCalculator.periodContains(
          date,
          now,
          FinancePeriod.monthly,
        );
      case _BillRange.custom:
        final range = _customRange;
        if (range == null) return true;
        final d = FinanceCalculator.dayOf(date);
        return !d.isBefore(FinanceCalculator.dayOf(range.start)) &&
            !d.isAfter(FinanceCalculator.dayOf(range.end));
      case _BillRange.all:
        return true;
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _billRange = _BillRange.custom;
    });
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
        note: result.note,
      );
      ToastService.success('Salary settled');
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

    final filteredBills = allBills
        .where((b) => _billInRange(b.createdAt))
        .where(
          (b) =>
              _payment == 'All' ||
              b.paymentType.trim().toLowerCase() == _payment.toLowerCase(),
        )
        .toList(growable: false);
    final billsByDay = <DateTime, List<Bill>>{};
    for (final b in filteredBills) {
      billsByDay
          .putIfAbsent(FinanceCalculator.dayOf(b.createdAt), () => <Bill>[])
          .add(b);
    }
    final billDays = billsByDay.keys.toList()..sort((a, b) => b.compareTo(a));
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
              const SizedBox(height: 10),
              FinanceSectionTitle(
                'Bills History',
                trailing: Text(
                  '${filteredBills.length} bills',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _billFilters(),
              if (billDays.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FinanceEmpty(message: 'No bills for these filters.'),
                )
              else
                for (final day in billDays) ...[
                  FinanceDayHeader(
                    date: day,
                    trailing: FinanceFormat.money(
                      billsByDay[day]!.fold<double>(
                        0,
                        (s, b) => s + b.grandTotal,
                      ),
                    ),
                  ),
                  ...billsByDay[day]!.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _BillCard(bill: b),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _billFilters() {
    final rangeLabels = <_BillRange, String>{
      _BillRange.today: 'Today',
      _BillRange.week: 'Week',
      _BillRange.month: 'Month',
      _BillRange.all: 'All',
    };
    final customLabel = _customRange == null
        ? 'Custom'
        : '${FinanceFormat.date(_customRange!.start)} - ${FinanceFormat.date(_customRange!.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in rangeLabels.entries) ...[
                FinanceChip(
                  label: e.value,
                  selected: _billRange == e.key,
                  onTap: () => setState(() => _billRange = e.key),
                ),
                const SizedBox(width: 6),
              ],
              FinanceChip(
                label: customLabel,
                selected: _billRange == _BillRange.custom,
                onTap: _pickCustomRange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final p in const ['All', 'Cash', 'Card', 'Online']) ...[
              Expanded(
                child: FinanceChip(
                  label: p,
                  selected: _payment == p,
                  onTap: () => setState(() => _payment = p),
                ),
              ),
              if (p != 'Online') const SizedBox(width: 6),
            ],
          ],
        ),
      ],
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
              _cell(
                'Cut',
                day.expenseCut,
                day.expenseCut > 0 ? AppColors.danger : AppColors.textSecondary,
              ),
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

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final customer = bill.customerName.trim().isNotEmpty
        ? bill.customerName.trim()
        : (bill.customerPhone.trim().isNotEmpty
              ? bill.customerPhone.trim()
              : 'Walk-in Customer');
    final services = bill.lines.map((l) => l.serviceName).join(', ');
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRoutes.billDetails, arguments: bill.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${FinanceFormat.time(bill.createdAt)}  •  ${bill.paymentType}'
                  '${services.isEmpty ? '' : '  •  $services'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FinanceFormat.money(bill.grandTotal),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
