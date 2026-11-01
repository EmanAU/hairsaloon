import 'dart:typed_data';
import '../../billing/domain/entities/bill.dart';

enum ReceiptConnection { system, bluetooth, ble, network, usb }

extension ReceiptConnectionLabel on ReceiptConnection {
  String get label => switch (this) {
    ReceiptConnection.system => 'Regular printer (Android print dialog)',
    ReceiptConnection.bluetooth => 'Thermal — Bluetooth',
    ReceiptConnection.ble => 'Thermal — Bluetooth Low Energy',
    ReceiptConnection.network => 'Thermal — Wi-Fi / Ethernet',
    ReceiptConnection.usb => 'Thermal — USB',
  };
}

class PrinterFailure implements Exception {
  const PrinterFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReceiptPrinterConfig {
  const ReceiptPrinterConfig({
    required this.connection,
    this.name = '',
    this.address = '',
    this.port = 9100,
    this.paperMm = 80,
    this.dots = 576,
    this.cut = false,
    this.deviceId,
    this.vendorId,
    this.productId,
  });
  final ReceiptConnection connection;
  final String name, address;
  final int port, paperMm, dots;
  final bool cut;
  final String? deviceId;
  final int? vendorId, productId;
  bool get isThermal => connection != ReceiptConnection.system;
  String get displayName => name.trim().isEmpty ? connection.label : name;

  String? get validationError {
    if (!isThermal) return null;
    if (![58, 80].contains(paperMm) ||
        !(paperMm == 58 ? [384] : [512, 576]).contains(dots)) {
      return 'Choose a supported paper width and print width.';
    }
    if (connection == ReceiptConnection.network) {
      final host = address.trim();
      if (host.isEmpty ||
          host.length > 253 ||
          !(RegExp(
                r'^[a-zA-Z0-9](?:[a-zA-Z0-9.\-]*[a-zA-Z0-9])?$',
              ).hasMatch(host) ||
              RegExp(r'^[a-fA-F0-9:]+$').hasMatch(host) &&
                  host.contains(':'))) {
        return 'Enter the printer IP address or hostname, without http:// or a port.';
      }
      if (port < 1 || port > 65535) return 'Enter a port from 1 to 65535.';
    }
    if ((connection == ReceiptConnection.bluetooth ||
            connection == ReceiptConnection.ble) &&
        !RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(address)) {
      return 'Select a Bluetooth printer from the device list.';
    }
    if (connection == ReceiptConnection.usb &&
        (deviceId == null || vendorId == null || productId == null)) {
      return 'Select an attached USB printer.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'connection': connection.name,
    'name': name,
    'address': address,
    'port': port,
    'paperMm': paperMm,
    'dots': dots,
    'cut': cut,
    'deviceId': deviceId,
    'vendorId': vendorId,
    'productId': productId,
  };

  factory ReceiptPrinterConfig.fromJson(Map<String, dynamic> json) =>
      ReceiptPrinterConfig(
        connection: ReceiptConnection.values.byName(
          json['connection'] as String,
        ),
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 9100,
        paperMm: json['paperMm'] as int? ?? 80,
        dots: json['dots'] as int? ?? 576,
        cut: json['cut'] as bool? ?? false,
        deviceId: json['deviceId'] as String?,
        vendorId: json['vendorId'] as int?,
        productId: json['productId'] as int?,
      );
}

class ReceiptPrinterDevice {
  const ReceiptPrinterDevice({
    required this.name,
    required this.address,
    this.deviceId,
    this.vendorId,
    this.productId,
  });
  final String name, address;
  final String? deviceId;
  final int? vendorId, productId;
  String get identity => deviceId ?? address;
}

class PrintableReceipt {
  const PrintableReceipt({
    required this.bill,
    required this.businessName,
    required this.businessPhone,
    required this.businessAddress,
    required this.currency,
    this.logoBase64,
    this.test = false,
  });
  final Bill bill;
  final String businessName, businessPhone, businessAddress, currency;
  final String? logoBase64;
  final bool test;
}

enum ReceiptPrintResult { sent, systemSubmitted, cancelled }

abstract interface class ReceiptPrinterPreferences {
  Future<ReceiptPrinterConfig?> load(String scope);
  Future<void> save(String scope, ReceiptPrinterConfig config);
  Future<void> clear(String scope);
}

abstract interface class ReceiptPrinterHardware {
  Stream<ReceiptPrinterDevice> discover(ReceiptConnection connection);
  Future<ReceiptPrintResult> printReceipt(
    ReceiptPrinterConfig config,
    PrintableReceipt receipt,
  );
  Future<void> openPermissions();
}

/// Exposed separately so encoders can be verified without printer hardware.
abstract interface class ReceiptEncoder {
  Future<List<int>> thermal(
    PrintableReceipt receipt,
    ReceiptPrinterConfig config,
  );
  Future<Uint8List> pdf(PrintableReceipt receipt);
}

class ReceiptPrinterActions {
  const ReceiptPrinterActions(this.preferences, this.hardware);
  final ReceiptPrinterPreferences preferences;
  final ReceiptPrinterHardware hardware;
  Future<ReceiptPrinterConfig?> load(String scope) => preferences.load(scope);
  Future<void> save(String scope, ReceiptPrinterConfig config) {
    final error = config.validationError;
    if (error != null) throw PrinterFailure(error);
    return preferences.save(scope, config);
  }

  Future<void> clear(String scope) => preferences.clear(scope);
  Stream<ReceiptPrinterDevice> discover(ReceiptConnection connection) =>
      hardware.discover(connection);
  Future<void> openPermissions() => hardware.openPermissions();
  Future<ReceiptPrintResult> print(
    ReceiptPrinterConfig config,
    PrintableReceipt receipt,
  ) {
    final error = config.validationError;
    if (error != null) throw PrinterFailure(error);
    return hardware.printReceipt(config, receipt);
  }
}
