import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/bill_receipt_share.dart';
import 'package:hairsaloon/src/features/billing/presentation/receipt_share_mixin.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/billing/presentation/widgets/pos_receipt_card.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({super.key, required this.billId});

  final String billId;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen>
    with ReceiptShareMixin {
  @override
  Widget build(BuildContext context) {
    final bill = context.select<BillingStore, Bill?>(
      (s) => s.getById(widget.billId),
    );
    final business = ReceiptBusinessInfo.from(
      context.watch<BusinessProfileNotifier>().profile,
    );
    final currency = context.select<SettingsStore, String>(
      (s) => s.currencyCode,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Bill Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: bill == null
          ? const Center(
              child: Text(
                'Bill not found.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          : Stack(
              children: [
                // Painted under the opaque content so it can be captured for
                // sharing without being visible.
                Positioned(
                  left: 0,
                  top: 0,
                  child: RepaintBoundary(
                    key: receiptKey,
                    child: PosReceiptCard(
                      bill: bill,
                      businessName: business.name,
                      currencyCode: currency,
                      businessPhone: business.phone,
                      businessAddress: business.address,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            children: [
                              _CustomerCard(bill: bill),
                              const SizedBox(height: 12),
                              _ItemsCard(bill: bill, currency: currency),
                              const SizedBox(height: 12),
                              _TotalsCard(bill: bill, currency: currency),
                            ],
                          ),
                        ),
                        _Actions(
                          sharing: sharing,
                          onShare: (buttonContext) => shareBill(
                            buttonContext: buttonContext,
                            bill: bill,
                            business: business,
                            currencyCode: currency,
                          ),
                          onReceipt: () => Navigator.of(context).pushNamed(
                            AppRoutes.receiptView,
                            arguments: bill.id,
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

String _money(String currency, double value) {
  final code = currency.trim().isEmpty ? 'Rs' : currency.trim();
  return '$code ${value.toStringAsFixed(0)}';
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final name = bill.customerName.trim();
    final phone = bill.customerPhone.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: initial.isEmpty
                    ? const Icon(
                        CupertinoIcons.person_fill,
                        size: 19,
                        color: AppColors.textPrimary,
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Walk-in customer' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isEmpty ? 'No phone number' : phone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: CupertinoIcons.number,
                label: 'Bill ${bill.shortNumber}',
              ),
              _MetaChip(
                icon: CupertinoIcons.calendar,
                label: BillReceiptShare.formatDateTime(bill.createdAt),
              ),
              if (bill.employeeName.trim().isNotEmpty)
                _MetaChip(
                  icon: CupertinoIcons.scissors,
                  label: bill.employeeName.trim(),
                ),
              if (bill.paymentType.trim().isNotEmpty)
                _MetaChip(
                  icon: CupertinoIcons.creditcard,
                  label: bill.paymentType.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.bill, required this.currency});

  final Bill bill;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Services (${bill.lines.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in bill.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.serviceName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (line.tag.trim().isNotEmpty || line.qty > 1)
                          Text(
                            [
                              if (line.tag.trim().isNotEmpty) line.tag.trim(),
                              if (line.qty > 1) 'x${line.qty}',
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _money(currency, line.total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.bill, required this.currency});

  final Bill bill;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _row('Sub Total', _money(currency, bill.subTotal)),
          if (bill.hasDiscount)
            _row(
              bill.discountLabel,
              '- ${_money(currency, bill.discountAmount)}',
              valueColor: AppColors.success,
            ),
          _row(
            'Tax (${bill.taxPercent.toStringAsFixed(0)}%)',
            _money(currency, bill.taxAmount),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _money(currency, bill.grandTotal),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sharing,
    required this.onShare,
    required this.onReceipt,
  });

  final bool sharing;
  final ValueChanged<BuildContext> onShare;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: sharing ? null : () => onShare(buttonContext),
                  style: appSecondaryButtonStyle(),
                  icon: const Icon(CupertinoIcons.share, size: 17),
                  label: Text(sharing ? 'Preparing…' : 'Share'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onReceipt,
                style: appPrimaryButtonStyle(),
                icon: const Icon(CupertinoIcons.doc_text, size: 17),
                label: const Text('Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
