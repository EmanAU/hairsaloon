import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class EmployeeHistoryScreen extends StatelessWidget {
  const EmployeeHistoryScreen({
    super.key,
    required this.employee,
    required this.bills,
  });

  final EmployeeItem employee;
  final List<Bill> bills;

  double get _totalSales => bills.fold(0, (sum, bill) => sum + bill.grandTotal);
  double get _commissionPercent => _toDouble(employee.commission);
  double get _totalEarning => (_totalSales * _commissionPercent) / 100;

  @override
  Widget build(BuildContext context) {
    final category = (employee.employeeType ?? '').trim();
    final speciality = (employee.speciality ?? '').trim();
    final headline = employee.fullName;
    final sublineParts = <String>[
      if (category.isNotEmpty) category,
      if (speciality.isNotEmpty) speciality,
      if (employee.phoneNumber.trim().isNotEmpty) employee.phoneNumber.trim(),
    ];
    final subline = sublineParts.join(' • ');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Employee History',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subline,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Orders: ${bills.length}  •  Total Sales: Rs.${_totalSales.toStringAsFixed(0)}  •  Earning: Rs.${_totalEarning.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (bills.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text(
                  'No orders found for this employee.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ...bills.map((b) => _orderTile(context, b)),
        ],
      ),
    );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$date  •  ${bill.paymentType}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF6B6B6B),
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
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.lines.length} items',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: Colors.black54,
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
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date  •  ${bill.paymentType}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B6B6B),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.serviceName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'x${line.qty}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rs.${line.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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
            : const Color(0xFFF6F6F6),
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
