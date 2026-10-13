import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/receipt_share_mixin.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/billing/presentation/widgets/pos_receipt_card.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

/// Full POS-style receipt preview with a share action.
class ReceiptViewScreen extends StatefulWidget {
  const ReceiptViewScreen({super.key, required this.billId});

  final String billId;

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen>
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
          'Receipt',
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
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
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
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Builder(
                      builder: (buttonContext) => FilledButton.icon(
                        onPressed: sharing
                            ? null
                            : () => shareBill(
                                buttonContext: buttonContext,
                                bill: bill,
                                business: business,
                                currencyCode: currency,
                              ),
                        style: appPrimaryButtonStyle(),
                        icon: const Icon(CupertinoIcons.share, size: 17),
                        label: Text(sharing ? 'Preparing…' : 'Share Receipt'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
