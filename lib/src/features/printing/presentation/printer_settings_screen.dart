import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../domain/receipt_printer.dart';
import 'receipt_print_button.dart';
import 'receipt_printer_store.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '9100');
  ReceiptConnection _connection = ReceiptConnection.system;
  ReceiptPrinterDevice? _device;
  int _paper = 80, _dots = 576;
  bool _cut = false, _dirty = false, _ready = false;
  late ReceiptPrinterStore _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _store = context.read<ReceiptPrinterStore>();
      await _store.load();
      if (!mounted) return;
      setState(() {
        _apply(_store.config);
        _ready = true;
      });
    });
  }

  void _apply(ReceiptPrinterConfig? config) {
    _connection = config?.connection ?? ReceiptConnection.system;
    _name.text = config?.name ?? '';
    _host.text = config?.address ?? '';
    _port.text = '${config?.port ?? 9100}';
    _paper = config?.paperMm ?? 80;
    _dots = config?.dots ?? 576;
    _cut = config?.cut ?? false;
    _device =
        config == null ||
            !{
              ReceiptConnection.bluetooth,
              ReceiptConnection.ble,
              ReceiptConnection.usb,
            }.contains(config.connection)
        ? null
        : ReceiptPrinterDevice(
            name: config.name,
            address: config.address,
            deviceId: config.deviceId,
            vendorId: config.vendorId,
            productId: config.productId,
          );
    _dirty = false;
  }

  ReceiptPrinterConfig _draft() => ReceiptPrinterConfig(
    connection: _connection,
    name: _name.text.trim(),
    address: _connection == ReceiptConnection.network
        ? _host.text.trim()
        : _device?.address ?? '',
    port: int.tryParse(_port.text) ?? 0,
    paperMm: _paper,
    dots: _dots,
    cut: _cut,
    deviceId: _device?.deviceId,
    vendorId: _device?.vendorId,
    productId: _device?.productId,
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (await _store.save(_draft()) && mounted) setState(() => _dirty = false);
  }

  @override
  void dispose() {
    if (_ready) unawaited(_store.stopScan());
    _name.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ReceiptPrinterStore>();
    final locked = store.busy || store.loading || store.scanning || !_ready;
    final thermal = _connection != ReceiptConnection.system;
    final hardware = {
      ReceiptConnection.bluetooth,
      ReceiptConnection.ble,
      ReceiptConnection.usb,
    }.contains(_connection);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Receipt printer')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text('Printer for this device', style: text.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      store.config == null
                          ? 'No receipt printer saved.'
                          : 'Saved: ${store.config!.displayName}',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'These settings apply to this account and business on this device.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<ReceiptConnection>(
                            key: ValueKey(_connection),
                            initialValue: _connection,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Printer connection',
                            ),
                            items: [
                              for (final value in ReceiptConnection.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: locked
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    unawaited(
                                      store.stopScan(clearDevices: true),
                                    );
                                    setState(() {
                                      _connection = value;
                                      _device = null;
                                      _dirty = true;
                                    });
                                  },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (!thermal) ...[
                            Text(
                              'Android will show its print dialog each time. Select your printer or Save as PDF there. A compatible print service may need to be installed in Android Settings.',
                              style: text.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (thermal) ...[
                            TextFormField(
                              controller: _name,
                              enabled: !locked,
                              decoration: const InputDecoration(
                                labelText: 'Printer name (optional)',
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_connection == ReceiptConnection.network) ...[
                              TextFormField(
                                controller: _host,
                                enabled: !locked,
                                autocorrect: false,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Printer IP address or hostname',
                                  hintText: '192.168.1.100',
                                ),
                                onChanged: (_) => setState(() => _dirty = true),
                                validator: (_) => _draft().validationError,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _port,
                                enabled: !locked,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Printer port',
                                ),
                                onChanged: (_) => setState(() => _dirty = true),
                                validator: (value) {
                                  final port = int.tryParse(value ?? '');
                                  return port == null ||
                                          port < 1 ||
                                          port > 65535
                                      ? 'Enter a port from 1 to 65535.'
                                      : null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Connect this device and the printer to the same network. Most ESC/POS printers use port 9100.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (hardware) ...[
                              if (_device != null)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.print_outlined),
                                  title: Text(_device!.name),
                                  subtitle: Text(_device!.address),
                                ),
                              OutlinedButton.icon(
                                onPressed: locked
                                    ? null
                                    : () => store.discover(_connection),
                                icon: const Icon(Icons.search),
                                label: Text(
                                  store.scanning
                                      ? 'Finding printers…'
                                      : _connection == ReceiptConnection.usb
                                      ? 'Find attached USB printers'
                                      : 'Find Bluetooth printers',
                                ),
                              ),
                              if (store.scanning) ...[
                                const LinearProgressIndicator(),
                                TextButton(
                                  onPressed: store.stopScan,
                                  child: const Text('Stop search'),
                                ),
                              ],
                              for (final device in store.devices)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(device.name),
                                  subtitle: Text(device.address),
                                  trailing: Icon(
                                    _device?.identity == device.identity
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                  ),
                                  onTap: store.busy
                                      ? null
                                      : () => setState(() {
                                          _device = device;
                                          if (_name.text.trim().isEmpty) {
                                            _name.text = device.name;
                                          }
                                          _dirty = true;
                                        }),
                                ),
                              Text(
                                _connection == ReceiptConnection.usb
                                    ? 'Connect an ESC/POS printer using a USB OTG adapter. Allow USB access when Android asks.'
                                    : 'Turn on the printer and Bluetooth. Pair Bluetooth Classic printers in Android Settings if needed. Only ESC/POS-compatible printers can print directly.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            DropdownButtonFormField<int>(
                              key: ValueKey('paper-$_paper'),
                              initialValue: _paper,
                              decoration: const InputDecoration(
                                labelText: 'Paper width',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 58,
                                  child: Text('58 mm'),
                                ),
                                DropdownMenuItem(
                                  value: 80,
                                  child: Text('80 mm'),
                                ),
                              ],
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() {
                                      _paper = value!;
                                      _dots = value == 58 ? 384 : 576;
                                      _dirty = true;
                                    }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<int>(
                              key: ValueKey('dots-$_paper-$_dots'),
                              initialValue: _dots,
                              decoration: const InputDecoration(
                                labelText: 'Printable width',
                              ),
                              items: [
                                for (final dots
                                    in _paper == 58 ? [384] : [576, 512])
                                  DropdownMenuItem(
                                    value: dots,
                                    child: Text('$dots dots'),
                                  ),
                              ],
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() {
                                      _dots = value!;
                                      _dirty = true;
                                    }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cut paper after receipt'),
                              subtitle: const Text(
                                'Enable only if the printer has an automatic cutter.',
                              ),
                              value: _cut,
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() {
                                      _cut = value;
                                      _dirty = true;
                                    }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          FilledButton(
                            onPressed: locked ? null : _save,
                            child: const Text('Save printer'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ReceiptPrintButton(
                            enabled: !locked && !_dirty && store.config != null,
                          ),
                          if (_dirty)
                            Text(
                              'Save your changes before printing a test receipt.',
                              style: text.bodySmall,
                            ),
                          if (store.config != null)
                            TextButton(
                              onPressed: locked
                                  ? null
                                  : () async {
                                      if (await store.clear() && mounted) {
                                        setState(() => _apply(null));
                                      }
                                    },
                              child: const Text('Remove saved printer'),
                            ),
                          if (store.busy) const LinearProgressIndicator(),
                          if (store.error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              store.error!,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                            TextButton(
                              onPressed: locked ? null : store.openPermissions,
                              child: const Text('Open app permissions'),
                            ),
                          ],
                          if (store.message != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(store.message!, style: text.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
