import 'package:flutter/material.dart';
import '../domain/entities/bill.dart';
import 'receipt_share_mixin.dart';
import 'widgets/pos_receipt_card.dart';

class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({
    super.key,
    required this.bill,
    required this.business,
    required this.currency,
  });
  final Bill bill;
  final ReceiptBusinessInfo business;
  final String currency;
  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> with ReceiptShareMixin {
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF668400)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Receipt saved',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close receipt',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RepaintBoundary(
                key: receiptKey,
                child: PosReceiptCard(
                  bill: widget.bill,
                  businessName: widget.business.name,
                  currencyCode: widget.currency,
                  businessPhone: widget.business.phone,
                  businessAddress: widget.business.address,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Detailed receipt'),
                ),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    onPressed: sharing
                        ? null
                        : () => shareBill(
                            buttonContext: buttonContext,
                            bill: widget.bill,
                            business: widget.business,
                            currencyCode: widget.currency,
                          ),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(sharing ? 'Sharing...' : 'Share receipt'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
