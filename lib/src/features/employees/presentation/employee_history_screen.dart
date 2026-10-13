import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

enum _HistoryDateFilter { all, today, week, month, custom }

class EmployeeHistoryScreen extends StatefulWidget {
  const EmployeeHistoryScreen({
    super.key,
    required this.employee,
    required this.bills,
  });

  final EmployeeItem employee;
  final List<Bill> bills;

  @override
  State<EmployeeHistoryScreen> createState() => _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends State<EmployeeHistoryScreen> {
  _HistoryDateFilter _filter = _HistoryDateFilter.all;
  DateTimeRange? _customRange;

  List<Bill> get _filteredBills {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool inRange(DateTime date, DateTime start, DateTime endInclusive) {
      final d = DateTime(date.year, date.month, date.day);
      return !d.isBefore(start) && !d.isAfter(endInclusive);
    }

    switch (_filter) {
      case _HistoryDateFilter.all:
        return widget.bills;
      case _HistoryDateFilter.today:
        return widget.bills
            .where((b) => inRange(b.createdAt, today, today))
            .toList(growable: false);
      case _HistoryDateFilter.week:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return widget.bills
            .where((b) => inRange(b.createdAt, start, today))
            .toList(growable: false);
      case _HistoryDateFilter.month:
        final start = DateTime(today.year, today.month, 1);
        return widget.bills
            .where((b) => inRange(b.createdAt, start, today))
            .toList(growable: false);
      case _HistoryDateFilter.custom:
        final range = _customRange;
        if (range == null) return widget.bills;
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        return widget.bills
            .where((b) => inRange(b.createdAt, start, end))
            .toList(growable: false);
    }
  }

  double get _totalSales =>
      _filteredBills.fold(0, (sum, bill) => sum + bill.grandTotal);
  double get _commissionPercent => _toDouble(widget.employee.commission);
  double get _totalEarning => (_totalSales * _commissionPercent) / 100;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _filter = _HistoryDateFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final bills = _filteredBills;
    final category = (employee.employeeType ?? '').trim();
    final speciality = (employee.speciality ?? '').trim();
    final sublineParts = <String>[
      if (category.isNotEmpty) category,
      if (speciality.isNotEmpty) speciality,
      if (employee.phoneNumber.trim().isNotEmpty) employee.phoneNumber.trim(),
    ];
    final subline = sublineParts.join(' • ');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: const Text(
          'Employee History',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: SafeScrollPadding.of(
          context,
          left: 12,
          top: 12,
          right: 12,
          bottom: 24,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E1E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subline,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Orders: ${bills.length}  •  Sales: Rs.${_totalSales.toStringAsFixed(0)}  •  Earning: Rs.${_totalEarning.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Filter by date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('All', _HistoryDateFilter.all),
              _filterChip('Today', _HistoryDateFilter.today),
              _filterChip('This week', _HistoryDateFilter.week),
              _filterChip('This month', _HistoryDateFilter.month),
              ChoiceChip(
                label: Text(
                  _filter == _HistoryDateFilter.custom && _customRange != null
                      ? _rangeLabel(_customRange!)
                      : 'Custom',
                ),
                selected: _filter == _HistoryDateFilter.custom,
                selectedColor: AppColors.primary.withValues(alpha: 0.25),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: _filter == _HistoryDateFilter.custom
                      ? AppColors.primary
                      : const Color(0xFFE1E1E1),
                ),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                onSelected: (_) => _pickCustomRange(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bills.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text(
                  'No orders found for this date range.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...bills.map((b) => _orderTile(context, b)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _HistoryDateFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFE1E1E1),
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      onSelected: (_) => setState(() {
        _filter = value;
        if (value != _HistoryDateFilter.custom) _customRange = null;
      }),
    );
  }

  String _rangeLabel(DateTimeRange range) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(range.start)}–${fmt(range.end)}';
  }

  static double _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final normalized = value.replaceAll(',', '').replaceAll('%', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Widget _orderTile(BuildContext context, Bill bill) {
    final date =
        '${bill.createdAt.day.toString().padLeft(2, '0')}-'
        '${bill.createdAt.month.toString().padLeft(2, '0')}-${bill.createdAt.year}';

    final customer = bill.customerName.trim().isNotEmpty
        ? bill.customerName.trim()
        : (bill.customerPhone.trim().isNotEmpty
              ? bill.customerPhone.trim()
              : 'Walk-in');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmployeeOrderDetailsScreen(bill: bill),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$date  •  ${bill.paymentType}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs.${bill.grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.lines.length} items',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeOrderDetailsScreen extends StatelessWidget {
  const EmployeeOrderDetailsScreen({super.key, required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final date =
        '${bill.createdAt.day.toString().padLeft(2, '0')}-'
        '${bill.createdAt.month.toString().padLeft(2, '0')}-${bill.createdAt.year}';

    final customer = bill.customerName.trim().isNotEmpty
        ? (bill.customerPhone.trim().isNotEmpty
              ? '${bill.customerName.trim()} • ${bill.customerPhone.trim()}'
              : bill.customerName.trim())
        : (bill.customerPhone.trim().isNotEmpty
              ? bill.customerPhone.trim()
              : 'Walk-in');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: SafeScrollPadding.of(
          context,
          left: 12,
          top: 12,
          right: 12,
          bottom: 24,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E1E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date  •  ${bill.paymentType}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Sub Total',
                        value: 'Rs.${bill.subTotal.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Tax',
                        value: 'Rs.${bill.taxAmount.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Total',
                        value: 'Rs.${bill.grandTotal.toStringAsFixed(0)}',
                        emphasize: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...bill.lines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E1E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.serviceName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'x${line.qty}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rs.${line.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.45)
              : const Color(0xFFEAEAEA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
