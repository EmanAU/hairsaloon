import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as pos;
import '../domain/receipt_printer.dart';

class AndroidReceiptPrinter implements ReceiptPrinterHardware {
  AndroidReceiptPrinter(
    this.encoder, {
    bool Function()? isAndroid,
    Future<bool> Function(Uint8List document, String name)? systemPrint,
  }) : _isAndroid = isAndroid ?? _onAndroid,
       _systemPrint = systemPrint ?? _printDocument;
  static bool _onAndroid() => Platform.isAndroid;
  final bool Function() _isAndroid;
  final Future<bool> Function(Uint8List document, String name) _systemPrint;
  static Future<bool> _printDocument(Uint8List document, String name) =>
      Printing.layoutPdf(
        name: name,
        format: PdfPageFormat.a4,
        dynamicLayout: false,
        onLayout: (_) async => document,
      );
  final ReceiptEncoder encoder;
  // Native Bluetooth channels are process-wide, including across workspaces.
  static bool _printing = false;
  static bool _discovering = false;

  void _android() {
    if (!_isAndroid()) {
      throw const PrinterFailure(
        'Printer connections are available in the Android business app.',
      );
    }
  }

  @override
  Future<void> openPermissions() async {
    _android();
    await openAppSettings();
  }

  @override
  Stream<ReceiptPrinterDevice> discover(ReceiptConnection connection) async* {
    _android();
    if (_printing || _discovering) {
      throw const PrinterFailure(
        'Wait for the current receipt to finish sending.',
      );
    }
    final pos.PrinterConnector connector = switch (connection) {
      ReceiptConnection.bluetooth => pos.BluetoothConnector(),
      ReceiptConnection.ble => pos.BleConnector(),
      ReceiptConnection.usb => pos.UsbConnector(),
      _ => throw const PrinterFailure(
        'Enter network printer details manually.',
      ),
    };
    _discovering = true;
    try {
      await for (final batch in connector.scan(
        timeout: const Duration(seconds: 8),
      )) {
        for (final pos.PrinterDevice device in batch) {
          yield switch (device) {
            pos.BluetoothPrinterDevice() => ReceiptPrinterDevice(
              name: device.name,
              address: device.address,
            ),
            pos.BlePrinterDevice() => ReceiptPrinterDevice(
              name: device.name,
              address: device.deviceId,
            ),
            pos.UsbPrinterDevice() => ReceiptPrinterDevice(
              name: device.name,
              address: device.identifier,
              deviceId: device.identifier,
              vendorId: int.tryParse(device.identifier.split(':').first),
              productId: int.tryParse(device.identifier.split(':').last),
            ),
            _ => throw const PrinterFailure('Unsupported printer connection.'),
          };
        }
      }
    } catch (error) {
      throw _failure(error, sending: false);
    } finally {
      try {
        await connector.stopScan();
        await connector.dispose();
      } finally {
        _discovering = false;
      }
    }
  }

  @override
  Future<ReceiptPrintResult> printReceipt(
    ReceiptPrinterConfig config,
    PrintableReceipt receipt,
  ) async {
    _android();
    if (_discovering) {
      throw const PrinterFailure(
        'Wait until the printer search has stopped, then print again.',
      );
    }
    if (_printing) {
      throw const PrinterFailure(
        'Another receipt is being sent. Wait before printing again.',
      );
    }
    _printing = true;
    pos.PrinterManager? manager;
    bool sending = false;
    try {
      if (config.connection == ReceiptConnection.system) {
        final document = await encoder.pdf(receipt);
        final submitted = await _systemPrint(
          document,
          receipt.test
              ? 'TrimMatrix printer test'
              : 'Receipt ${receipt.bill.shortNumber}',
        );
        return submitted
            ? ReceiptPrintResult.systemSubmitted
            : ReceiptPrintResult.cancelled;
      }
      final bytes = await encoder.thermal(receipt, config);
      manager = pos.PrinterManager();
      final pos.PrinterDevice device = switch (config.connection) {
        ReceiptConnection.bluetooth => pos.BluetoothPrinterDevice(
          name: config.displayName,
          address: config.address,
        ),
        ReceiptConnection.ble => pos.BlePrinterDevice(
          name: config.displayName,
          deviceId: config.address,
        ),
        ReceiptConnection.network => pos.NetworkPrinterDevice(
          name: config.displayName,
          host: config.address.trim(),
          port: config.port,
        ),
        ReceiptConnection.usb => pos.UsbPrinterDevice(
          name: config.displayName,
          identifier: config.deviceId!,
          usbPlatform: pos.UsbPlatform.android,
        ),
        ReceiptConnection.system => throw StateError('Handled above'),
      };
      await manager.connect(device, timeout: const Duration(seconds: 15));
      sending = true;
      // The transport paces writes and drains its buffers before disconnecting.
      // No automatic retry: a failed write may already have printed part/all.
      await manager.printBytes(bytes);
      await manager.disconnect();
      return ReceiptPrintResult.sent;
    } catch (error) {
      throw _failure(error, sending: sending);
    } finally {
      try {
        await manager?.dispose();
      } catch (_) {
        /* Preserve the original result. */
      }
      _printing = false;
    }
  }

  PrinterFailure _failure(Object error, {required bool sending}) {
    if (error is PrinterFailure) return error;
    if (sending) {
      return const PrinterFailure(
        'Sending was interrupted. The receipt may have printed partially or completely. Check the printer before reprinting.',
      );
    }
    if (error is pos.PrinterPermissionException) {
      return const PrinterFailure(
        'Printer permission was denied. Allow Nearby devices (or Location on older Android) in app permissions, then try again. For USB, allow access in the Android prompt.',
      );
    }
    if (error is pos.PrinterConnectionException ||
        error is pos.PrinterNotFoundException ||
        error is SocketException ||
        error is TimeoutException) {
      return const PrinterFailure(
        'Could not connect. Check printer power, Bluetooth pairing or the network address, or reconnect the USB cable.',
      );
    }
    if (error is pos.PrinterScanException) {
      return const PrinterFailure(
        'Could not find printers. Turn on Bluetooth and allow Nearby devices. Older Android may also need Location enabled.',
      );
    }
    if (error is MissingPluginException) {
      return const PrinterFailure(
        'Printing is unavailable in this build. Install the updated Android business app.',
      );
    }
    return const PrinterFailure(
      'Could not prepare or open printing. Check your printer or Android print service and try again.',
    );
  }
}
