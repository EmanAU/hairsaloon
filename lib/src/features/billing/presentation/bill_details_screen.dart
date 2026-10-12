import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class BillDetailsScreen extends StatelessWidget {
  const BillDetailsScreen({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context) {
    final bill = context.watch<BillingStore>().getById(billId);
    if (bill == null) {
      return const Scaffold(body: Center(child: Text('Bill not found.')));
    }

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
          'Bill ${bill.id.substring(0, 6)}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${bill.customerName.isEmpty ? '-' : bill.customerName}',
                ),
                Text(
                  'Phone: ${bill.customerPhone.isEmpty ? '-' : bill.customerPhone}',
                ),
                Text('Employee: ${bill.employeeName}'),
                Text('Payment: ${bill.paymentType}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                ...bill.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.serviceName),
                              if (line.tag.trim().isNotEmpty)
                                Text(
                                  line.tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text('x${line.qty}'),
                        const SizedBox(width: 8),
                        Text('Rs.${line.total.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                _row('Sub Total', 'Rs.${bill.subTotal.toStringAsFixed(0)}'),
                _row(
                  'Tax ${bill.taxPercent.toStringAsFixed(0)}%',
                  'Rs.${bill.taxAmount.toStringAsFixed(0)}',
                ),
                _row(
                  'Grand Total',
                  'Rs.${bill.grandTotal.toStringAsFixed(0)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
