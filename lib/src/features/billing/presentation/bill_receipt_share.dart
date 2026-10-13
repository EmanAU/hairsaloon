import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BillReceiptShare {
  const BillReceiptShare._();

  static String buildTextReceipt({
    required Bill bill,
    required String businessName,
    required String currencyCode,
    String businessPhone = '',
    String businessAddress = '',
  }) {
    final code = currencyCode.trim().isEmpty ? 'Rs' : currencyCode.trim();
    String money(double v) => '$code ${v.toStringAsFixed(0)}';
    final billNo = bill.id.length >= 6 ? bill.id.substring(0, 6) : bill.id;
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
      ..writeln('TAX INVOICE / RECEIPT')
      ..writeln('Bill No: $billNo')
      ..writeln('Date: ${bill.createdAt}')
      ..writeln(
        'Customer: ${bill.customerName.trim().isEmpty ? '-' : bill.customerName}',
      )
      ..writeln(
        'Phone: ${bill.customerPhone.trim().isEmpty ? '-' : bill.customerPhone}',
      )
      ..writeln(
        'Staff: ${bill.employeeName.trim().isEmpty ? '-' : bill.employeeName}',
      )
      ..writeln(
        'Payment: ${bill.paymentType.trim().isEmpty ? '-' : bill.paymentType}',
      )
      ..writeln('------------------------------');
    for (final line in bill.lines) {
      buffer.writeln(
        '${line.serviceName} x${line.qty}  ${money(line.total)}',
      );
    }
    buffer
      ..writeln('------------------------------')
      ..writeln('Sub Total: ${money(bill.subTotal)}')
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
      if (file != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: text,
            subject: 'Receipt - $businessName',
            title: 'Share Receipt',
            sharePositionOrigin: origin,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: 'Receipt - $businessName',
            title: 'Share Receipt',
            sharePositionOrigin: origin,
          ),
        );
      }
    } catch (e) {
      ToastService.error('Could not share receipt.');
    }
  }

  static Future<void> shareOnWhatsApp({
    required BuildContext context,
    required GlobalKey receiptKey,
    required Bill bill,
    required String businessName,
    required String currencyCode,
    String businessPhone = '',
    String businessAddress = '',
    String? customerPhone,
  }) async {
    // Prefer share sheet with image (user picks WhatsApp). Text fallback via wa.me.
    final origin = _shareOrigin(context);
    final file = await captureReceiptImage(receiptKey);
    final text = buildTextReceipt(
      bill: bill,
      businessName: businessName,
      currencyCode: currencyCode,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
    );

    if (file != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: text,
            subject: 'Receipt - $businessName',
            title: 'WhatsApp Receipt',
            sharePositionOrigin: origin,
          ),
        );
        return;
      } catch (_) {
        // fall through to text WhatsApp
      }
    }

    final digits = (customerPhone ?? bill.customerPhone)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final uri = digits.isEmpty
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
        : Uri.parse(
            'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
          );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      ToastService.error('Could not open WhatsApp.');
    }
  }
}
