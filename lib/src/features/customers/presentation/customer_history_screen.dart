import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class CustomerHistoryScreen extends StatelessWidget {
  const CustomerHistoryScreen({
    super.key,
    required this.customerLabel,
    required this.bills,
  });

  final String customerLabel;
  final List<Bill> bills;

  double get _totalSpent => bills.fold(0, (sum, bill) => sum + bill.grandTotal);
  double get _totalTax => bills.fold(0, (sum, bill) => sum + bill.taxAmount);
  double get _totalSubTotal =>
      bills.fold(0, (sum, bill) => sum + bill.subTotal);

  @override
  Widget build(BuildContext context) {
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
          'Customer History',
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
                  customerLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniStat(label: 'Visits', value: bills.length.toString()),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'Sub Total',
                      value: 'Rs.${_totalSubTotal.toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'Tax',
                      value: 'Rs.${_totalTax.toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'Total',
                      value: 'Rs.${_totalSpent.toStringAsFixed(0)}',
                      emphasize: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...bills.map(_historyCard),
        ],
      ),
    );
  }

  Widget _historyCard(Bill bill) {
    final date =
        '${bill.createdAt.day.toString().padLeft(2, '0')}-'
        '${bill.createdAt.month.toString().padLeft(2, '0')}-${bill.createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const Spacer(),
              Text(
                'Rs.${bill.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bill.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.serviceName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text('x${line.qty}', style: const TextStyle(fontSize: 10.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Rs.${line.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 14),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF555555),
                    ),
                    children: [
                      const TextSpan(text: 'Employee: '),
                      TextSpan(
                        text: bill.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: '  •  Payment: '),
                      TextSpan(
                        text: bill.paymentType,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Sub: Rs.${bill.subTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF555555),
                    ),
                  ),
                  Text(
                    'Tax: Rs.${bill.taxAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ],
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
    return Expanded(
      child: Container(
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
      ),
    );
  }
}
