import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BillReceiptShare {
  const BillReceiptShare._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String formatDateTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} '
        '${d.year}, $hour:$minute $period';
  }

  static String buildTextReceipt({
    required Bill bill,
    required String businessName,
    required String currencyCode,
    String businessPhone = '',
    String businessAddress = '',
  }) {
    final code = currencyCode.trim().isEmpty ? 'Rs' : currencyCode.trim();
    String money(double v) => '$code ${v.toStringAsFixed(0)}';
    String orDash(String v) => v.trim().isEmpty ? '-' : v.trim();
    final buffer = StringBuffer()
      ..writeln(businessName.toUpperCase())
      ..writeln('------------------------------');
    if (businessAddress.trim().isNotEmpty) {
      buffer.writeln(businessAddress.trim());
    }
    if (businessPhone.trim().isNotEmpty) {
      buffer.writeln(businessPhone.trim());
    }
    buffer
      ..writeln('RECEIPT')
      ..writeln('Bill No: ${bill.shortNumber}')
      ..writeln('Date: ${formatDateTime(bill.createdAt)}')
      ..writeln('Customer: ${orDash(bill.customerName)}')
      ..writeln('Phone: ${orDash(bill.customerPhone)}')
      ..writeln('Staff: ${orDash(bill.employeeName)}')
      ..writeln('Payment: ${orDash(bill.paymentType)}')
      ..writeln('------------------------------');
    for (final line in bill.lines) {
      buffer.writeln('${line.serviceName} x${line.qty}  ${money(line.total)}');
    }
    buffer
      ..writeln('------------------------------')
      ..writeln('Sub Total: ${money(bill.subTotal)}');
    if (bill.hasDiscount) {
      buffer.writeln('${bill.discountLabel}: - ${money(bill.discountAmount)}');
    }
    buffer
      ..writeln(
        'Tax (${bill.taxPercent.toStringAsFixed(0)}%): ${money(bill.taxAmount)}',
      )
      ..writeln('GRAND TOTAL: ${money(bill.grandTotal)}')
      ..writeln('------------------------------')
      ..writeln('Thank you for your visit!');
    return buffer.toString();
  }

  static Future<File?> captureReceiptImage(GlobalKey receiptKey) async {
    try {
      final boundary =
          receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file;
    } catch (e, st) {
      debugPrint('Receipt capture failed: $e\n$st');
      return null;
    }
  }

  static Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Shares the receipt as a PNG image with the text receipt as caption.
  /// Falls back to text only if the image can't be captured.
  static Future<void> shareReceipt({
    required BuildContext context,
    required GlobalKey receiptKey,
    required Bill bill,
    required String businessName,
    required String currencyCode,
    String businessPhone = '',
    String businessAddress = '',
  }) async {
    final origin = _shareOrigin(context);
    final text = buildTextReceipt(
      bill: bill,
      businessName: businessName,
      currencyCode: currencyCode,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
    );
    final file = await captureReceiptImage(receiptKey);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: file == null
              ? null
              : [XFile(file.path, mimeType: 'image/png')],
          text: text,
          subject: 'Receipt - $businessName',
          title: 'Share Receipt',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      ToastService.error('Could not share receipt.');
    }
  }
}
