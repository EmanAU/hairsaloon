import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class BusinessLogo extends StatelessWidget {
  const BusinessLogo({super.key, required this.value, this.size = 64});
  final String? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (value != null) bytes = base64Decode(value!);
    } on FormatException {
      bytes = null;
    }
    final placeholder = Icon(
      Icons.storefront_outlined,
      size: size * 0.4,
      color: AppColors.textSecondary,
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: bytes == null
            ? placeholder
            : Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class BusinessLogoPicker extends StatefulWidget {
  const BusinessLogoPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.recoverLostImage = false,
    this.picker,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool recoverLostImage;
  final ImagePicker? picker;

  @override
  State<BusinessLogoPicker> createState() => _BusinessLogoPickerState();
}

class _BusinessLogoPickerState extends State<BusinessLogoPicker> {
  late final ImagePicker _picker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    if (widget.recoverLostImage &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _recover();
    }
  }

  Future<void> _recover() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.files?.isNotEmpty ?? false) {
        await _accept(response.files!.first);
      }
    } on MissingPluginException {
      // No native picker in widget tests.
    } catch (_) {
      if (mounted) ToastService.error('Please choose your logo again.');
    }
  }

  Future<void> _accept(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Logo is too large. Choose an image under 2 MB.',
      );
    }
    // Validate the image before persisting it as part of the local profile.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
    codec.dispose();
    if (mounted) widget.onChanged(base64Encode(bytes));
  }

  Future<void> _pick() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file != null) await _accept(file);
    } on FormatException catch (error) {
      if (mounted) ToastService.error(error.message);
    } catch (_) {
      if (mounted) {
        ToastService.error(
          'Could not open this image. Please try another logo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BusinessLogo(value: widget.value),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shop logo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              const Text(
                'Optional · choose from gallery',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if (widget.enabled)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _pick,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        _busy
                            ? 'Opening…'
                            : widget.value == null
                            ? 'Choose logo'
                            : 'Change logo',
                      ),
                    ),
                    if (widget.value != null)
                      TextButton(
                        onPressed: _busy ? null : () => widget.onChanged(null),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
