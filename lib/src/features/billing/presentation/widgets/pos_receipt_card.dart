import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

/// Thermal / POS style receipt card used on screen and for share capture.
class PosReceiptCard extends StatelessWidget {
  const PosReceiptCard({
    super.key,
    required this.bill,
    required this.businessName,
    required this.currencyCode,
    this.businessPhone = '',
    this.businessAddress = '',
  });

  final Bill bill;
  final String businessName;
  final String currencyCode;
  final String businessPhone;
  final String businessAddress;

  static const _months = <String>[
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

  String _money(double value) {
    final code = currencyCode.trim().isEmpty ? 'Rs' : currencyCode.trim();
    return '$code ${value.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} '
        '${dt.year}  ${hour12.toString().padLeft(2, '0')}:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final billNo = bill.shortNumber;
    final dateText = _formatDate(bill.createdAt);
    final customerName = bill.customerName.trim().isEmpty
        ? '-'
        : bill.customerName.trim();
    final customerPhone = bill.customerPhone.trim().isEmpty
        ? '-'
        : bill.customerPhone.trim();

    return Container(
      width: 340,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            businessName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (businessAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              businessAddress.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          if (businessPhone.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              businessPhone.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _DashLine(),
          const SizedBox(height: 10),
          Text(
            'TAX INVOICE / RECEIPT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Bill No', billNo),
          _kv('Date', dateText),
          _kv('Customer', customerName),
          _kv('Phone', customerPhone),
          _kv('Staff', bill.employeeName.trim().isEmpty ? '-' : bill.employeeName),
          _kv('Payment', bill.paymentType.trim().isEmpty ? '-' : bill.paymentType),
          const SizedBox(height: 10),
          const _DashLine(),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'QTY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'AMOUNT',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...bill.lines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.serviceName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (line.tag.trim().isNotEmpty)
                          Text(
                            line.tag,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${line.qty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _money(line.total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const _DashLine(),
          const SizedBox(height: 8),
          _kv('Sub Total', _money(bill.subTotal)),
          if (bill.hasDiscount)
            _kv(bill.discountLabel, '- ${_money(bill.discountAmount)}'),
          _kv(
            'Tax (${bill.taxPercent.toStringAsFixed(0)}%)',
            _money(bill.taxAmount),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'GRAND TOTAL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _money(bill.grandTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _DashLine(),
          const SizedBox(height: 12),
          const Text(
            'Thank you for your visit!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please come again',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(
            ':  ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashLine extends StatelessWidget {
  const _DashLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 3.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1.2,
              color: const Color(0xFFBFBFBF),
            ),
          ),
        );
      },
    );
  }
}
