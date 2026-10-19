import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/toast_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

/// Two large Before / After cards in one row for the customer-view editor.
class ServiceBeforeAfterCards extends StatefulWidget {
  const ServiceBeforeAfterCards({
    super.key,
    required this.repository,
    required this.serviceId,
    required this.businessId,
  });

  final OnlineRepository repository;
  final String serviceId;
  final String businessId;

  @override
  State<ServiceBeforeAfterCards> createState() =>
      _ServiceBeforeAfterCardsState();
}

class _ServiceBeforeAfterCardsState extends State<ServiceBeforeAfterCards> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  bool _busy = false;

  Future<List<Map<String, dynamic>>> _load() =>
      widget.repository.media(widget.serviceId);

  void _refresh() => setState(() => _rows = _load());

  ({Map<String, dynamic>? before, Map<String, dynamic>? after}) _pair(
    List<Map<String, dynamic>> rows,
  ) {
    Map<String, dynamic>? before;
    Map<String, dynamic>? after;
    // Prefer paired rows; fall back to any before/after.
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

  Future<void> _addPair() async {
    if (_busy) return;
    final picker = ImagePicker();
    ToastService.info('Choose the before photo', context);
    final before = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (before == null || !mounted) return;
    ToastService.info('Choose the after photo', context);
    final after = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (after == null || !mounted) return;

    setState(() => _busy = true);
    final pair = const Uuid().v4();
    try {
      await widget.repository.uploadMedia(
        widget.businessId,
        widget.serviceId,
        'before',
        await before.readAsBytes(),
        before.name.split('.').last.toLowerCase(),
        pairId: pair,
      );
      await widget.repository.uploadMedia(
        widget.businessId,
        widget.serviceId,
        'after',
        await after.readAsBytes(),
        after.name.split('.').last.toLowerCase(),
        pairId: pair,
      );
      if (mounted) _refresh();
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not upload photos. Try again.', context);
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
        final hasAny = pair.before != null || pair.after != null;
        final sharedPairId =
            (pair.before?['pair_id'] as String?) ??
            (pair.after?['pair_id'] as String?) ??
            const Uuid().v4();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PhotoCard(
                    label: 'Before',
                    url: pair.before?['url'] as String?,
                    busy: _busy,
                    onAdd: () =>
                        _pickAndUpload('before', pairId: sharedPairId),
                    onRemove: pair.before == null
                        ? null
                        : () => _remove(pair.before!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoCard(
                    label: 'After',
                    url: pair.after?['url'] as String?,
                    busy: _busy,
                    onAdd: () =>
                        _pickAndUpload('after', pairId: sharedPairId),
                    onRemove: pair.after == null
                        ? null
                        : () => _remove(pair.after!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!hasAny)
              OutlinedButton.icon(
                onPressed: _busy ? null : _addPair,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add before & after photos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.label,
    required this.url,
    required this.busy,
    required this.onAdd,
    this.onRemove,
  });

  final String label;
  final String? url;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : (url == null ? onAdd : null),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 36),
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 36,
                      color: AppColors.iconMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add $label',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (url != null && onRemove != null)
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
              if (url != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: FilledButton.tonal(
                    onPressed: busy ? null : onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface.withValues(
                        alpha: 0.92,
                      ),
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(36),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Replace'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
