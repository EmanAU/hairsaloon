import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeWorkingsScreen extends StatelessWidget {
  const EmployeeWorkingsScreen({
    super.key,
    required this.employee,
    required this.period,
    required this.anchorDate,
  });

  final EmployeeItem employee;
  final WorkingsPeriod period;
  final DateTime anchorDate;

  @override
  Widget build(BuildContext context) {
    final employeeName = employee.fullName.trim();
    final commissionPercent = _toDouble(employee.commission);

    final bills = context
        .watch<BillingStore>()
        .bills
        .where((b) => b.employeeName == employeeName)
        .where((b) => _isInPeriod(b.createdAt, anchorDate, period))
        .toList(growable: false);

    final expenses = context
        .watch<ExpensesStore>()
        .items
        .where((e) => e.employeeName == employeeName)
        .where((e) => _isInPeriod(e.date, anchorDate, period))
        .toList(growable: false);

    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final salesTotal = bills.fold<double>(0, (sum, b) => sum + b.grandTotal);
    final commissionBase = bills.fold<double>(
      0,
      (sum, b) => sum + b.commissionBase,
    );
    final earningTotal = (commissionBase * commissionPercent) / 100;
    final expenseTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final unpaidExpenseTotal = expenses
        .where((e) => e.status.trim().toLowerCase() == 'unpaid')
        .fold<double>(0, (sum, e) => sum + e.amount);
    final netDue = (earningTotal - unpaidExpenseTotal);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: Text(
          employee.fullName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _summaryCard(
            context,
            period: period,
            anchorDate: anchorDate,
            commissionPercent: commissionPercent,
            salesTotal: salesTotal,
            earningTotal: earningTotal,
            expenseTotal: expenseTotal,
            unpaidExpenseTotal: unpaidExpenseTotal,
            netDue: netDue,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Bills (${bills.length})'),
          const SizedBox(height: 8),
          if (bills.isEmpty)
            const _EmptyCard(text: 'No bills found for this period.')
          else
            ...bills.map((b) => _billTile(b)),
          const SizedBox(height: 12),
          _sectionTitle('Expenses (${expenses.length})'),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            const _EmptyCard(text: 'No expenses found for this period.')
          else
            ...expenses.map((e) => _expenseTile(e)),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required WorkingsPeriod period,
    required DateTime anchorDate,
    required double commissionPercent,
    required double salesTotal,
    required double earningTotal,
    required double expenseTotal,
    required double unpaidExpenseTotal,
    required double netDue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel(anchorDate, period),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  label: 'Sales',
                  value: 'Rs.${salesTotal.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  label: 'Earning (${commissionPercent.toStringAsFixed(0)}%)',
                  value: 'Rs.${earningTotal.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  label: 'Expenses',
                  value: 'Rs.${expenseTotal.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  label: 'Unpaid',
                  value: 'Rs.${unpaidExpenseTotal.toStringAsFixed(0)}',
                  valueColor: unpaidExpenseTotal > 0
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Net Due',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Rs.${(netDue < 0 ? 0 : netDue).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: (netDue <= 0) ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    );
  }

  Widget _billTile(Bill bill) {
    final customer = bill.customerName.trim().isNotEmpty
        ? bill.customerName.trim()
        : (bill.customerPhone.trim().isNotEmpty
              ? bill.customerPhone.trim()
              : 'Walk-in');
    final dateText =
        '${bill.createdAt.day.toString().padLeft(2, '0')}-${bill.createdAt.month.toString().padLeft(2, '0')}-${bill.createdAt.year}';
    final timeText =
        '${bill.createdAt.hour.toString().padLeft(2, '0')}:${bill.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '$timeText\n$dateText',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8D8D8D)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.paymentType}  •  ${bill.lines.isNotEmpty ? bill.lines.first.serviceName : 'No service'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rs.${bill.grandTotal.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _expenseTile(ExpenseItem item) {
    final dateText =
        '${item.date.day.toString().padLeft(2, '0')}-${item.date.month.toString().padLeft(2, '0')}-${item.date.year}';
    final statusLower = item.status.trim().toLowerCase();
    final statusColor = statusLower == 'paid'
        ? AppColors.success
        : AppColors.danger;
    final label = (item.expenseType?.trim().isNotEmpty ?? false)
        ? item.expenseType!.trim()
        : (item.description?.trim().isNotEmpty ?? false)
        ? item.description!.trim()
        : 'Expense';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              dateText,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8D8D8D)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.status} (${item.paymentType})',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rs.${item.amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  static double _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final normalized = value.replaceAll(',', '').replaceAll('%', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  static bool _isInPeriod(
    DateTime date,
    DateTime anchor,
    WorkingsPeriod period,
  ) {
    final target = DateTime(date.year, date.month, date.day);
    switch (period) {
      case WorkingsPeriod.daily:
        return target == DateTime(anchor.year, anchor.month, anchor.day);
      case WorkingsPeriod.weekly:
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return !target.isBefore(start) && !target.isAfter(end);
      case WorkingsPeriod.monthly:
        return target.year == anchor.year && target.month == anchor.month;
    }
  }

  static String _periodLabel(DateTime anchor, WorkingsPeriod period) {
    switch (period) {
      case WorkingsPeriod.daily:
        return 'Daily • ${_dmy(anchor)}';
      case WorkingsPeriod.weekly:
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return 'Weekly • ${_dmy(start)} - ${_dmy(end)}';
      case WorkingsPeriod.monthly:
        const months = <String>[
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return 'Monthly • ${months[anchor.month - 1]} ${anchor.year}';
    }
  }

  static String _dmy(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B6B6B),
        ),
      ),
    );
  }
}

enum WorkingsPeriod { daily, weekly, monthly }
