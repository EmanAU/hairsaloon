import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/toast_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

/// Two clear sections — Before and After — for the customer-view editor.
class ServiceBeforeAfterCards extends StatefulWidget {
  const ServiceBeforeAfterCards({
    super.key,
    required this.repository,
    required this.serviceId,
    required this.businessId,
    this.onChanged,
  });

  final OnlineRepository repository;
  final String serviceId;
  final String businessId;
  final VoidCallback? onChanged;

  @override
  State<ServiceBeforeAfterCards> createState() =>
      _ServiceBeforeAfterCardsState();
}

class _ServiceBeforeAfterCardsState extends State<ServiceBeforeAfterCards> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  bool _busy = false;

  Future<List<Map<String, dynamic>>> _load() =>
      widget.repository.media(widget.serviceId);

  void _refresh() {
    setState(() => _rows = _load());
    widget.onChanged?.call();
  }

  ({Map<String, dynamic>? before, Map<String, dynamic>? after}) _pair(
    List<Map<String, dynamic>> rows,
  ) {
    Map<String, dynamic>? before;
    Map<String, dynamic>? after;
    final paired = rows.where((r) => r['pair_id'] != null).toList();
    final source = paired.isNotEmpty ? paired : rows;
    for (final row in source) {
      final kind = row['kind'] as String?;
      if (kind == 'before' && before == null) before = row;
      if (kind == 'after' && after == null) after = row;
    }
    return (before: before, after: after);
  }

  Future<void> _pickAndUpload(String kind, {String? pairId}) async {
    if (_busy) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.uploadMedia(
        widget.businessId,
        widget.serviceId,
        kind,
        await file.readAsBytes(),
        file.name.split('.').last.toLowerCase(),
        pairId: pairId,
      );
      if (mounted) _refresh();
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not upload the photo. Try again.', context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteMedia(
        row['id'] as String,
        row['storage_path'] as String,
      );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not remove the photo.', context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Could not load photos.'),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          );
        }

        final pair = _pair(snapshot.data ?? const []);
        final sharedPairId =
            (pair.before?['pair_id'] as String?) ??
            (pair.after?['pair_id'] as String?) ??
            const Uuid().v4();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add one photo for Before and one for After.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SectionCard(
                    label: 'Before',
                    url: pair.before?['url'] as String?,
                    busy: _busy,
                    onTap: () =>
                        _pickAndUpload('before', pairId: sharedPairId),
                    onRemove: pair.before == null
                        ? null
                        : () => _remove(pair.before!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SectionCard(
                    label: 'After',
                    url: pair.after?['url'] as String?,
                    busy: _busy,
                    onTap: () =>
                        _pickAndUpload('after', pairId: sharedPairId),
                    onRemove: pair.after == null
                        ? null
                        : () => _remove(pair.after!),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.url,
    required this.busy,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final String? url;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  bool get _hasPhoto => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onTap,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: _hasPhoto
                      ? Border.all(color: AppColors.border)
                      : null,
                ),
                child: _hasPhoto ? _filled() : _empty(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.textSecondary.withValues(alpha: 0.35),
        radius: 14,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: AppColors.iconMuted,
          ),
          SizedBox(height: 10),
          Text(
            'Add image',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filled() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 36),
          ),
        ),
        // Soft blur + dim so it reads as “already added — change photo”.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
          child: ColoredBox(
            color: AppColors.textPrimary.withValues(alpha: 0.32),
          ),
        ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                color: AppColors.surface,
                size: 30,
              ),
              SizedBox(height: 8),
              Text(
                'Change photo',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: AppColors.surface.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
