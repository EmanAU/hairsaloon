import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/qr_destination.dart';
import 'widgets/online_widgets.dart';

class PublicQr extends StatelessWidget {
  const PublicQr({
    super.key,
    required this.destination,
    required this.label,
    this.size = 160,
  });
  final QrDestination destination;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: QrImageView(
            data: destination.value,
            size: size,
            backgroundColor: AppColors.surface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                destination.value,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            IconButton(
              tooltip: 'Copy link',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: destination.value));
                if (context.mounted) showMessage(context, 'Code copied');
              },
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

class ScanQr extends StatefulWidget {
  const ScanQr({super.key, this.joining = false, this.profileCode = false});
  final bool joining;

  /// When true, accept a raw profile UUID or any TrimMatrix UUID id.
  final bool profileCode;
  @override
  State<ScanQr> createState() => _ScanQrState();
}

class _ScanQrState extends State<ScanQr> {
  bool _done = false;
  String? _error;
  final _manual = TextEditingController();
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void _read(String value) {
    if (_done) return;
    final trimmed = value.trim();
    if (widget.profileCode) {
      final parsed = QrDestination.parse(trimmed);
      final id = parsed?.id ?? (_uuid.hasMatch(trimmed) ? trimmed : null);
      if (id == null) {
        setState(() => _error = 'Scan a profile code QR.');
        return;
      }
      _done = true;
      Navigator.pop(context, QrDestination('join', id.toLowerCase()));
      return;
    }
    final target = QrDestination.parse(trimmed);
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
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(CupertinoIcons.back),
      ),
      title: const Text(
        'Scan QR',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (!widget.joining && !widget.profileCode)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Text(
                    'Discover your salon',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Point your camera at a salon or barber QR code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        _read(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.profileCode
                            ? 'Camera unavailable. Allow camera access to scan the QR.'
                            : 'Camera unavailable. Allow camera access or paste the QR link below.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!widget.profileCode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _manual,
                decoration: InputDecoration(
                  labelText: 'Paste QR link',
                  suffixIcon: IconButton(
                    tooltip: 'Open QR link',
                    onPressed: () => _read(_manual.text),
                    icon: const Icon(CupertinoIcons.arrow_right),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
