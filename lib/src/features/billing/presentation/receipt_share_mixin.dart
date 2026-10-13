import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/bill_receipt_share.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';

/// Business details printed on the receipt.
class ReceiptBusinessInfo {
  const ReceiptBusinessInfo({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory ReceiptBusinessInfo.from(BusinessProfile? profile) {
    if (profile == null) {
      return const ReceiptBusinessInfo(
        name: 'Hair Salon',
        phone: '',
        address: '',
      );
    }
    final name = profile.businessName.trim();
    final address = profile.address.trim().isNotEmpty
        ? profile.address.trim()
        : [
            profile.area.trim(),
            profile.city.trim(),
          ].where((p) => p.isNotEmpty).join(', ');
    return ReceiptBusinessInfo(
      name: name.isEmpty ? 'Hair Salon' : name,
      phone: profile.phoneNumber.trim(),
      address: address,
    );
  }

  final String name;
  final String phone;
  final String address;
}

/// Holds the receipt [RepaintBoundary] key and share-in-progress state.
mixin ReceiptShareMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey receiptKey = GlobalKey();
  bool sharing = false;

  Future<void> shareBill({
    required BuildContext buttonContext,
    required Bill bill,
    required ReceiptBusinessInfo business,
    required String currencyCode,
  }) async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!buttonContext.mounted) return;
      await BillReceiptShare.shareReceipt(
        context: buttonContext,
        receiptKey: receiptKey,
        bill: bill,
        businessName: business.name,
        currencyCode: currencyCode,
        businessPhone: business.phone,
        businessAddress: business.address,
      );
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }
}
