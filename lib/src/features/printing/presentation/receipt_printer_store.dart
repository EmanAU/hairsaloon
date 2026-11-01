import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/receipt_printer.dart';

class ReceiptPrinterStore extends ChangeNotifier {
  ReceiptPrinterStore({required this.actions, required this.scope});
  final ReceiptPrinterActions actions;
  final String Function() scope;
  ReceiptPrinterConfig? config;
  final List<ReceiptPrinterDevice> devices = [];
  bool loading = false, busy = false, scanning = false;
  String? error, message;
  bool _disposed = false;
  StreamSubscription<ReceiptPrinterDevice>? _scan;
  int _scanEpoch = 0;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _failure(Object failure) {
    error = failure is PrinterFailure
        ? failure.message
        : 'Printer operation failed. Check the printer and try again.';
    _publish();
  }

  Future<bool> load() async {
    if (loading || busy || _disposed) return false;
    final current = scope();
    loading = true;
    config = null;
    error = null;
    message = null;
    _publish();
    try {
      final saved = await actions.load(current);
      if (_disposed || current != scope()) return false;
      config = saved;
      return true;
    } catch (failure) {
      _failure(failure);
      return false;
    } finally {
      loading = false;
      _publish();
    }
  }

  Future<bool> save(ReceiptPrinterConfig value) async {
    if (busy || loading || _disposed) return false;
    final current = scope();
    busy = true;
    error = null;
    message = null;
    _publish();
    try {
      await stopScan();
      if (_disposed || current != scope()) return false;
      await actions.save(current, value);
      if (_disposed || current != scope()) return false;
      config = value;
      message = 'Printer saved for this device.';
      return true;
    } catch (failure) {
      _failure(failure);
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<bool> clear() async {
    if (busy || loading || _disposed) return false;
    busy = true;
    error = null;
    message = null;
    _publish();
    final current = scope();
    try {
      await actions.clear(current);
      if (_disposed || current != scope()) return false;
      config = null;
      message = 'Saved printer removed.';
      return true;
    } catch (failure) {
      _failure(failure);
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> discover(ReceiptConnection connection) async {
    if (busy || loading || _disposed) return;
    await stopScan();
    final epoch = ++_scanEpoch;
    final current = scope();
    devices.clear();
    scanning = true;
    error = null;
    message = null;
    _publish();
    _scan = actions
        .discover(connection)
        .listen(
          (device) {
            if (_disposed || epoch != _scanEpoch || current != scope()) return;
            if (!devices.any((d) => d.identity == device.identity)) {
              devices.add(device);
            }
            _publish();
          },
          onError: (Object failure) {
            if (_disposed || epoch != _scanEpoch) return;
            scanning = false;
            _failure(failure);
          },
          onDone: () {
            if (_disposed || epoch != _scanEpoch) return;
            scanning = false;
            if (devices.isEmpty && error == null) {
              message =
                  'No printers found. Check the connection and try again.';
            }
            _publish();
          },
        );
  }

  Future<void> stopScan({bool clearDevices = false}) async {
    _scanEpoch++;
    final subscription = _scan;
    _scan = null;
    scanning = false;
    if (clearDevices) devices.clear();
    await subscription?.cancel();
    _publish();
  }

  Future<ReceiptPrintResult?> print(PrintableReceipt receipt) async {
    if (busy || loading || _disposed) return null;
    final current = scope();
    busy = true;
    error = null;
    message = null;
    _publish();
    try {
      await stopScan();
      final selected = await actions.load(current);
      if (_disposed || current != scope()) return null;
      config = selected;
      if (selected == null) {
        throw const PrinterFailure(
          'Set up a receipt printer in Business Settings first.',
        );
      }
      final result = await actions.print(selected, receipt);
      message = switch (result) {
        ReceiptPrintResult.sent =>
          'Receipt data sent. Check the printer before reprinting.',
        ReceiptPrintResult.systemSubmitted =>
          'Receipt submitted to Android printing.',
        ReceiptPrintResult.cancelled => 'Printing cancelled.',
      };
      return result;
    } catch (failure) {
      _failure(failure);
      return null;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> openPermissions() async {
    try {
      await actions.openPermissions();
    } catch (failure) {
      _failure(failure);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scanEpoch++;
    unawaited(_scan?.cancel());
    super.dispose();
  }
}
