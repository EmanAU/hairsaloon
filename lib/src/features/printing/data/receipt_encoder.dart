import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as pos;
import '../../../core/utils/pk_phone.dart';
import '../domain/receipt_printer.dart';

class ReceiptPrintRow {
  const ReceiptPrintRow(
    this.text, {
    this.value,
    this.bold = false,
    this.center = false,
  });
  final String text;
  final String? value;
  final bool bold, center;
}

/// Saved amounts are authoritative. Printing never changes the bill.
List<ReceiptPrintRow> receiptRows(PrintableReceipt receipt) {
  final bill = receipt.bill;
  final currency = receipt.currency.trim().isEmpty
      ? 'PKR'
      : receipt.currency.trim();
  String money(double value) => '$currency ${value.toStringAsFixed(2)}';
  final date = bill.createdAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    if (receipt.test)
      const ReceiptPrintRow(
        'TEST RECEIPT — NOT A SALE',
        bold: true,
        center: true,
      ),
    ReceiptPrintRow(receipt.businessName, bold: true, center: true),
    if (receipt.businessAddress.trim().isNotEmpty)
      ReceiptPrintRow(receipt.businessAddress, center: true),
    if (receipt.businessPhone.trim().isNotEmpty)
      ReceiptPrintRow(PkPhone.localNumber(receipt.businessPhone), center: true),
    const ReceiptPrintRow('RECEIPT', bold: true, center: true),
    ReceiptPrintRow('Bill', value: bill.shortNumber),
    ReceiptPrintRow(
      'Date',
      value:
          '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}',
    ),
    ReceiptPrintRow(
      'Customer',
      value: bill.customerName.trim().isEmpty
          ? 'Walk-in customer'
          : bill.customerName,
    ),
    if (bill.customerPhone.trim().isNotEmpty)
      ReceiptPrintRow('Phone', value: PkPhone.localNumber(bill.customerPhone)),
    if (bill.employeeName.trim().isNotEmpty)
      ReceiptPrintRow('Barber', value: bill.employeeName),
    ReceiptPrintRow('Payment', value: bill.paymentType),
    const ReceiptPrintRow('Services', bold: true),
    for (final item in bill.lines) ...[
      ReceiptPrintRow(item.serviceName, bold: true),
      ReceiptPrintRow(
        '${item.qty} × ${money(item.price)}',
        value: money(item.total),
      ),
    ],
    ReceiptPrintRow('Subtotal', value: money(bill.subTotal)),
    if (bill.hasDiscount)
      ReceiptPrintRow(
        bill.discountLabel,
        value: '-${money(bill.discountAmount)}',
      ),
    ReceiptPrintRow(
      'Tax (${bill.taxPercent.toStringAsFixed(2)}%)',
      value: money(bill.taxAmount),
    ),
    ReceiptPrintRow('TOTAL', value: money(bill.grandTotal), bold: true),
    const ReceiptPrintRow('Thank you for visiting!', center: true),
  ];
}

/// Flutter text shaping preserves Urdu/Arabic and avoids printer code-page
/// differences. Short raster strips keep memory and printer buffers bounded.
class FlutterReceiptEncoder implements ReceiptEncoder {
  Future<List<img.Image>> _render(PrintableReceipt receipt, int width) async {
    final output = <img.Image>[];
    final logo = receipt.logoBase64;
    if (logo != null && logo.isNotEmpty) {
      try {
        final raw = base64Decode(
          logo.contains(',') ? logo.split(',').last : logo,
        );
        final decoded = img.decodeImage(raw);
        if (decoded != null) {
          final resized = img.copyResize(
            decoded,
            width: math.min(width ~/ 3, decoded.width),
          );
          final canvas = img.Image(
            width: width,
            height: math.min(resized.height, 192) + 12,
          );
          img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
          final fitted = resized.height > 192
              ? img.copyResize(resized, height: 192)
              : resized;
          img.compositeImage(canvas, fitted, dstX: (width - fitted.width) ~/ 2);
          output.add(canvas);
        }
      } catch (_) {
        /* A damaged optional logo must not prevent a receipt. */
      }
    }
    const black = ui.Color(0xff000000), white = ui.Color(0xffffffff);
    for (final row in receiptRows(receipt)) {
      final padding = width * .025;
      final available = width - padding * 2;
      // Match the physical font size on 58 mm and 80 mm stock.
      final size = row.bold ? 25.0 : 21.0;
      TextPainter painter(String text, double maxWidth, {bool right = false}) {
        final rtl = RegExp(r'[\u0590-\u08ff]').hasMatch(text);
        return TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: black,
              fontSize: size,
              fontFamily: 'sans-serif',
              fontWeight: row.bold ? FontWeight.w700 : FontWeight.w400,
              height: 1.2,
            ),
          ),
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: row.center
              ? TextAlign.center
              : right
              ? TextAlign.right
              : rtl
              ? TextAlign.right
              : TextAlign.left,
        )..layout(minWidth: maxWidth, maxWidth: maxWidth);
      }

      final rightWidth = row.value == null ? 0.0 : available * .49;
      final leftWidth = row.value == null
          ? available
          : available - rightWidth - 10;
      final left = painter(row.text, leftWidth);
      final right = row.value == null
          ? null
          : painter(row.value!, rightWidth, right: true);
      final height = (math.max(left.height, right?.height ?? 0) + 14).ceil();
      if (height > 32000 || output.length > 2000) {
        left.dispose();
        right?.dispose();
        throw const PrinterFailure('This receipt is too long to print.');
      }
      for (var y = 0; y < height; y += 256) {
        final stripHeight = math.min(256, height - y);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(white, BlendMode.src);
        canvas.translate(0, -y.toDouble());
        left.paint(canvas, Offset(padding, 7));
        right?.paint(canvas, Offset(width - padding - rightWidth, 7));
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, stripHeight);
        picture.dispose();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        if (data == null) {
          throw const PrinterFailure('Could not prepare the receipt image.');
        }
        output.add(
          img.Image.fromBytes(
            width: width,
            height: stripHeight,
            bytes: data.buffer,
            bytesOffset: data.offsetInBytes,
            numChannels: 4,
          ),
        );
      }
      left.dispose();
      right?.dispose();
    }
    return output;
  }

  @override
  Future<List<int>> thermal(
    PrintableReceipt receipt,
    ReceiptPrinterConfig config,
  ) async {
    final profile = await pos.CapabilityProfile.load();
    final generator = pos.Generator(
      config.paperMm == 58 ? pos.PaperSize.mm58 : pos.PaperSize.mm80,
      profile,
    );
    final bytes = <int>[...generator.reset()];
    for (final image in await _render(receipt, config.dots)) {
      bytes.addAll(generator.imageRaster(image, align: pos.PrintAlign.left));
    }
    bytes.addAll(generator.feed(4));
    if (config.cut) bytes.addAll(generator.cut());
    if (bytes.length > 4 * 1024 * 1024) {
      throw const PrinterFailure('This receipt is too large to print.');
    }
    return bytes;
  }

  @override
  Future<Uint8List> pdf(PrintableReceipt receipt) async {
    final images = await _render(receipt, 576);
    final document = pw.Document(
      title: receipt.test
          ? 'Printer test'
          : 'Receipt ${receipt.bill.shortNumber}',
      author: receipt.businessName,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 100,
        build: (_) => [
          for (final image in images)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                pw.MemoryImage(img.encodePng(image)),
                width: 288,
                height: image.height / 2,
                fit: pw.BoxFit.contain,
              ),
            ),
        ],
        footer: (context) => pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    );
    return document.save();
  }
}
