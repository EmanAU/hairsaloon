import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/presentation/bill_receipt_share.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/billing/presentation/widgets/pos_receipt_card.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({super.key, required this.billId});

  final String billId;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;

  Future<void> _runShare(Future<void> Function() action) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Let the frame paint before capture.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await action();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = context.watch<BillingStore>().getById(widget.billId);
    if (bill == null) {
      return const Scaffold(body: Center(child: Text('Bill not found.')));
    }

    final profile = context.watch<BusinessProfileNotifier>().profile;
    final currency = context.watch<SettingsStore>().currencyCode;
    final businessName = (profile?.businessName.trim().isNotEmpty ?? false)
        ? profile!.businessName.trim()
        : 'Hair Salon';
    final businessPhone = profile?.phoneNumber.trim() ?? '';
    final businessAddress = () {
      if (profile == null) return '';
      if (profile.address.trim().isNotEmpty) return profile.address.trim();
      final parts = <String>[
        if (profile.area.trim().isNotEmpty) profile.area.trim(),
        if (profile.city.trim().isNotEmpty) profile.city.trim(),
      ];
      return parts.join(', ');
    }();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
        ),
        title: Text(
          'Bill ${bill.id.length >= 6 ? bill.id.substring(0, 6) : bill.id}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: tablet ? 520 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: [
                    Center(
                      child: Material(
                        color: AppColors.surface,
                        elevation: 1.5,
                        shadowColor: AppColors.shadow,
                        child: RepaintBoundary(
                          key: _receiptKey,
                          child: PosReceiptCard(
                            bill: bill,
                            businessName: businessName,
                            currencyCode: currency,
                            businessPhone: businessPhone,
                            businessAddress: businessAddress,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? 8 : 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing
                          ? null
                          : () => _runShare(
                              () => BillReceiptShare.shareReceipt(
                                context: context,
                                receiptKey: _receiptKey,
                                bill: bill,
                                businessName: businessName,
                                currencyCode: currency,
                                businessPhone: businessPhone,
                                businessAddress: businessAddress,
                              ),
                            ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFFD0D0D0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.share, size: 18),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sharing
                          ? null
                          : () => _runShare(
                              () => BillReceiptShare.shareOnWhatsApp(
                                context: context,
                                receiptKey: _receiptKey,
                                bill: bill,
                                businessName: businessName,
                                currencyCode: currency,
                                businessPhone: businessPhone,
                                businessAddress: businessAddress,
                              ),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.chat, size: 18),
                      label: Text(
                        _sharing ? 'Preparing…' : 'WhatsApp',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
