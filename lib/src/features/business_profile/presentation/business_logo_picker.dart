import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class BusinessLogo extends StatelessWidget {
  const BusinessLogo({
    super.key,
    required this.value,
    this.size = 64,
    this.circular = false,
  });

  final String? value;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (value != null && value!.isNotEmpty) {
        bytes = base64Decode(value!);
      }
    } on FormatException {
      bytes = null;
    }

    final radius = circular ? size / 2 : 9.0;
    final placeholder = Icon(
      Icons.storefront_rounded,
      size: size * 0.38,
      color: AppColors.textSecondary,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Center(child: placeholder)
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Center(child: placeholder),
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
    this.title = 'Business photo',
    this.emptyHint = 'Optional · camera or gallery',
    this.filledHint = 'Tap the camera to change or remove',
    this.addLabel = 'Add photo',
    this.changeLabel = 'Change photo',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool recoverLostImage;
  final ImagePicker? picker;
  final String title;
  final String emptyHint;
  final String filledHint;
  final String addLabel;
  final String changeLabel;

  @override
  State<BusinessLogoPicker> createState() => _BusinessLogoPickerState();
}

class _BusinessLogoPickerState extends State<BusinessLogoPicker> {
  late final ImagePicker _picker;
  bool _busy = false;
  /// Local preview so the photo shows immediately after pick.
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _previewBytes = _decode(widget.value);
    if (widget.recoverLostImage &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _recover();
    }
  }

  @override
  void didUpdateWidget(covariant BusinessLogoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previewBytes = _decode(widget.value);
    }
  }

  Uint8List? _decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
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
    if (bytes.isEmpty) {
      throw const FormatException('Could not read this image.');
    }
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Logo is too large. Choose an image under 2 MB.',
      );
    }

    // Validate decode before saving.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
    codec.dispose();

    final encoded = base64Encode(bytes);
    if (!mounted) return;
    setState(() => _previewBytes = bytes);
    widget.onChanged(encoded);
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file != null) await _accept(file);
    } on FormatException catch (error) {
      if (mounted) ToastService.error(error.message);
    } on PlatformException catch (error) {
      if (!mounted) return;
      final denied = error.code.toLowerCase().contains('permission') ||
          (error.message?.toLowerCase().contains('permission') ?? false);
      ToastService.error(
        denied
            ? 'Permission needed to use the camera or gallery.'
            : 'Could not open this image. Please try again.',
      );
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

  Future<void> _showSourceSheet() async {
    if (_busy || !widget.enabled) return;
    final hasPhoto = _previewBytes != null ||
        (widget.value != null && widget.value!.isNotEmpty);

    final action = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => AppSheetBody(
        title: widget.title,
        subtitle: 'Choose where to get the image from.',
        icon: Icons.image_outlined,
        showCancel: false,
        child: Column(
          children: [
            AppSheetOption(
              label: 'Take photo',
              icon: Icons.photo_camera_rounded,
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            AppSheetOption(
              label: 'Choose from gallery',
              icon: Icons.photo_library_rounded,
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasPhoto)
              AppSheetOption(
                label: 'Remove photo',
                icon: Icons.delete_outline_rounded,
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'camera':
        _pick(ImageSource.camera);
      case 'gallery':
        _pick(ImageSource.gallery);
      case 'remove':
        setState(() => _previewBytes = null);
        widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    final hasPhoto = _previewBytes != null;

    return Row(
      children: [
        GestureDetector(
          onTap: widget.enabled && !_busy ? _showSourceSheet : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: const Color(0xFFE1E1E1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _busy
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : hasPhoto
                          ? Image.memory(
                              _previewBytes!,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront_rounded,
                                size: 34,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              size: 34,
                              color: AppColors.textSecondary,
                            ),
                ),
                if (widget.enabled)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _showSourceSheet,
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                hasPhoto ? widget.filledHint : widget.emptyHint,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.enabled) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _busy ? null : _showSourceSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    _busy
                        ? 'Opening…'
                        : hasPhoto
                            ? widget.changeLabel
                            : widget.addLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
