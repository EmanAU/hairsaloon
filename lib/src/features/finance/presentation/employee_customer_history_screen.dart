import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

enum _Range { today, week, month, custom, all }

/// Bills served by one employee, grouped by day, with date and payment filters.
class EmployeeCustomerHistoryScreen extends StatefulWidget {
  const EmployeeCustomerHistoryScreen({super.key, required this.employee});

  final EmployeeItem employee;

  @override
  State<EmployeeCustomerHistoryScreen> createState() =>
      _EmployeeCustomerHistoryScreenState();
}

class _EmployeeCustomerHistoryScreenState
    extends State<EmployeeCustomerHistoryScreen> {
  _Range _range = _Range.all;
  DateTimeRange? _customRange;
  String _payment = 'All';

  bool _inRange(DateTime date) {
    final now = DateTime.now();
    switch (_range) {
      case _Range.today:
        return FinanceCalculator.periodContains(date, now, FinancePeriod.daily);
      case _Range.week:
        return FinanceCalculator.periodContains(
          date,
          now,
          FinancePeriod.weekly,
        );
      case _Range.month:
        return FinanceCalculator.periodContains(
          date,
          now,
          FinancePeriod.monthly,
        );
      case _Range.custom:
        final range = _customRange;
        if (range == null) return true;
        final d = FinanceCalculator.dayOf(date);
        return !d.isBefore(FinanceCalculator.dayOf(range.start)) &&
            !d.isAfter(FinanceCalculator.dayOf(range.end));
      case _Range.all:
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
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _range = _Range.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bills = context
        .watch<BillingStore>()
        .bills
        .where(
          (b) =>
              b.belongsToEmployee(widget.employee.id, widget.employee.fullName),
        )
        .where((b) => _inRange(b.createdAt))
        .where(
          (b) =>
              _payment == 'All' ||
              b.paymentType.trim().toLowerCase() == _payment.toLowerCase(),
        )
        .toList(growable: false);

    final byDay = <DateTime, List<Bill>>{};
    for (final b in bills) {
      byDay
          .putIfAbsent(FinanceCalculator.dayOf(b.createdAt), () => <Bill>[])
          .add(b);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final total = bills.fold<double>(0, (s, b) => s + b.grandTotal);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, 'Customer History'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 760 : double.infinity),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              FinanceCard(
                child: Row(
                  children: [
                    EmployeeAvatar(employee: widget.employee, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.employee.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bills.length} ${bills.length == 1 ? 'customer' : 'customers'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FinanceFormat.money(total),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _filters(),
              const SizedBox(height: 6),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FinanceEmpty(
                    message: 'No customers for these filters.',
                  ),
                )
              else
                for (final day in days) ...[
                  FinanceDayHeader(
                    date: day,
                    trailing:
                        '${byDay[day]!.length} bills  •  ${FinanceFormat.money(byDay[day]!.fold<double>(0, (s, b) => s + b.grandTotal))}',
                  ),
                  ...byDay[day]!.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _CustomerBillCard(bill: b),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    const rangeLabels = <_Range, String>{
      _Range.all: 'All',
      _Range.today: 'Today',
      _Range.week: 'Week',
      _Range.month: 'Month',
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
                  selected: _range == e.key,
                  onTap: () => setState(() => _range = e.key),
                ),
                const SizedBox(width: 6),
              ],
              FinanceChip(
                label: customLabel,
                selected: _range == _Range.custom,
                onTap: _pickCustomRange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _payment,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: {
            'All',
            'Cash',
            'Card',
            'Online',
            ...context
                .read<BillingStore>()
                .bills
                .map((b) => b.paymentType)
                .where((p) => p.isNotEmpty),
          }.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (p) => setState(() => _payment = p ?? 'All'),
        ),
      ],
    );
  }
}

class _CustomerBillCard extends StatelessWidget {
  const _CustomerBillCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final name = bill.customerName.trim();
    final phone = PkPhone.localNumber(bill.customerPhone);
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
                  name.isEmpty ? 'Walk-in Customer' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  '${FinanceFormat.date(bill.createdAt)}  •  ${FinanceFormat.time(bill.createdAt)}'
                  '${bill.paymentType.trim().isEmpty ? '' : '  •  ${bill.paymentType.trim()}'}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (services.isNotEmpty)
                  Text(
                    services,
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
