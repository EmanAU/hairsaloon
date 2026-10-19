import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BillReceiptShare {
  const BillReceiptShare._();

  static const _whatsAppChannel = MethodChannel('hairsaloon/whatsapp_share');

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

  /// Digits-only international number for WhatsApp (`923001234567`).
  static String? whatsAppPhoneDigits(String? raw) {
    final normalized = PkPhone.normalize(raw);
    if (PkPhone.isValid(normalized)) {
      return normalized.substring(1);
    }
    var digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    // Local PK mobile without country code → same jid as a saved +92 contact.
    if (RegExp(r'^03\d{9}$').hasMatch(digits)) {
      digits = '92${digits.substring(1)}';
    } else if (RegExp(r'^3\d{9}$').hasMatch(digits)) {
      digits = '92$digits';
    }
    if (digits.length >= 11 && digits.length <= 15) return digits;
    return null;
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

  static const thankYouMessage = 'Thank you for your visit!';

  static Future<bool> _shareToWhatsAppAndroid({
    required String phoneDigits,
    required String text,
    String? filePath,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _whatsAppChannel.invokeMethod<bool>(
        'shareToWhatsApp',
        <String, dynamic>{
          'phone': phoneDigits,
          'text': text,
          'filePath': filePath,
        },
      );
      return ok == true;
    } on PlatformException catch (e) {
      debugPrint('WhatsApp share failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('WhatsApp share failed: $e');
      return false;
    }
  }

  static Future<bool> _openWhatsAppChat({
    required String phoneDigits,
    required String text,
  }) async {
    final uri = Uri.parse(
      'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('wa.me launch failed: $e');
    }
    return false;
  }

  /// Shares the receipt image with a short thank-you caption.
  /// When [Bill.customerPhone] is set, opens WhatsApp on that chat directly.
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
    final file = await captureReceiptImage(receiptKey);
    final textReceipt = buildTextReceipt(
      bill: bill,
      businessName: businessName,
      currencyCode: currencyCode,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
    );
    final caption = file != null ? thankYouMessage : textReceipt;
    final phoneDigits = whatsAppPhoneDigits(bill.customerPhone);

    try {
      if (phoneDigits != null) {
        // Android: open that customer's WhatsApp chat with receipt image.
        final sent = await _shareToWhatsAppAndroid(
          phoneDigits: phoneDigits,
          text: caption,
          filePath: file?.path,
        );
        if (sent) return;

        // Cross-platform fallback: open chat with text receipt prefilled.
        final opened = await _openWhatsAppChat(
          phoneDigits: phoneDigits,
          text: textReceipt,
        );
        if (opened) return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: file == null
              ? null
              : [XFile(file.path, mimeType: 'image/png')],
          text: caption,
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
