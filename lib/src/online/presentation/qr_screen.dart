import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../domain/qr_destination.dart';
import 'widgets/online_widgets.dart';

class PublicQr extends StatelessWidget {
  const PublicQr({super.key, required this.destination, required this.label});
  final QrDestination destination;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      QrImageView(
        data: destination.value,
        size: 200,
        backgroundColor: Colors.white,
      ),
      CopyCode(code: destination.value, label: label),
    ],
  );
}

class ScanQr extends StatefulWidget {
  const ScanQr({super.key, this.joining = false});
  final bool joining;
  @override
  State<ScanQr> createState() => _ScanQrState();
}

class _ScanQrState extends State<ScanQr> {
  bool _done = false;
  String? _error;
  final _manual = TextEditingController();
  void _read(String value) {
    if (_done) return;
    final target = QrDestination.parse(value);
    if (target == null || (target.kind == 'join') != widget.joining) {
      setState(
        () => _error = widget.joining
            ? 'Scan a salon employee invitation QR.'
            : 'Scan a salon or barber QR.',
      );
      return;
    }
    _done = true;
    Navigator.pop(context, target);
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan QR')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _read(barcode.rawValue!);
                  break;
                }
              }
            },
            errorBuilder: (context, error) => const Center(
              child: Text(
                'Camera unavailable. Allow camera access or paste the QR link below.',
              ),
            ),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _manual,
            decoration: InputDecoration(
              labelText: 'Paste QR link',
              suffixIcon: IconButton(
                onPressed: () => _read(_manual.text),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
