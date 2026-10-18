import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ServiceMedia extends StatefulWidget {
  const ServiceMedia({
    super.key,
    required this.repository,
    required this.serviceId,
    this.businessId,
  });
  final OnlineRepository repository;
  final String serviceId;
  final String? businessId;
  @override
  State<ServiceMedia> createState() => _ServiceMediaState();
}

class _ServiceMediaState extends State<ServiceMedia> {
  late Future<List<Map<String, dynamic>>> _rows = widget.repository.media(
    widget.serviceId,
  );
  void _refresh() =>
      setState(() => _rows = widget.repository.media(widget.serviceId));
  Future<void> _upload(String kind) async {
    final picker = ImagePicker();
    final file = kind == 'video'
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2),
          )
        : await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 2000,
            imageQuality: 85,
          );
    if (file == null) return;
    await widget.repository.uploadMedia(
      widget.businessId!,
      widget.serviceId,
      kind,
      await file.readAsBytes(),
      file.name.split('.').last.toLowerCase(),
    );
    if (mounted) _refresh();
  }

  Future<void> _uploadPair() async {
    final picker = ImagePicker();
    showMessage(context, 'Choose the BEFORE photo');
    final before = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (before == null || !mounted) return;
    showMessage(context, 'Choose the AFTER photo');
    final after = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (after == null) return;
    final pair = const Uuid().v4();
    try {
      await widget.repository.uploadMedia(
        widget.businessId!,
        widget.serviceId,
        'before',
        await before.readAsBytes(),
        before.name.split('.').last.toLowerCase(),
        pairId: pair,
      );
      await widget.repository.uploadMedia(
        widget.businessId!,
        widget.serviceId,
        'after',
        await after.readAsBytes(),
        after.name.split('.').last.toLowerCase(),
        pairId: pair,
      );
    } finally {
      if (mounted) _refresh();
    }
  }

  Widget _photo(Map<String, dynamic> row) => Column(
    children: [
      Text((row['kind'] as String).toUpperCase()),
      Image.network(
        row['url'] as String,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => const Text('Photo unavailable'),
      ),
      if (widget.businessId != null)
        ActionButton(
          label: 'Remove ${row['kind']}',
          onPressed: () async {
            await widget.repository.deleteMedia(
              row['id'] as String,
              row['storage_path'] as String,
            );
            if (mounted) _refresh();
          },
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(
        'Photos, videos & results',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      TextButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh media'),
      ),
      if (widget.businessId != null) ...[
        Wrap(
          spacing: 8,
          children: [
            for (final kind in ['photo', 'video'])
              ActionButton(label: 'Add $kind', onPressed: () => _upload(kind)),
            ActionButton(
              label: 'Add before / after pair',
              onPressed: _uploadPair,
            ),
          ],
        ),
      ],
      RemoteContent(
        future: _rows,
        onRetry: _refresh,
        builder: (rows) => Column(
          children: [
            if (rows.isEmpty) const Text('No media added yet.'),
            for (final pair
                in rows
                    .where((row) => row['pair_id'] != null)
                    .map((row) => row['pair_id'])
                    .toSet())
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final kind in ['before', 'after'])
                        Expanded(
                          child: Builder(
                            builder: (_) {
                              final row = rows
                                  .where(
                                    (row) =>
                                        row['pair_id'] == pair &&
                                        row['kind'] == kind,
                                  )
                                  .firstOrNull;
                              return row == null
                                  ? Text('$kind photo missing')
                                  : _photo(row);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            for (final row in rows.where((row) => row['pair_id'] == null))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((row['kind'] as String).toUpperCase()),
                      if (row['kind'] == 'video')
                        _ServiceVideo(
                          key: ValueKey(row['url']),
                          url: row['url'] as String,
                        )
                      else
                        Image.network(
                          row['url'] as String,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stack) => const Text(
                            'Photo unavailable. Refresh to retry.',
                          ),
                        ),
                      if (widget.businessId != null)
                        ActionButton(
                          label: 'Remove media',
                          onPressed: () async {
                            await widget.repository.deleteMedia(
                              row['id'] as String,
                              row['storage_path'] as String,
                            );
                            if (mounted) _refresh();
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ServiceVideo extends StatefulWidget {
  const _ServiceVideo({super.key, required this.url});
  final String url;
  @override
  State<_ServiceVideo> createState() => _ServiceVideoState();
}

class _ServiceVideoState extends State<_ServiceVideo> {
  late final _controller = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );
  late final _ready = _controller.initialize();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Video unavailable. Refresh the page to retry.');
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, child) => IconButton(
              tooltip: value.isPlaying ? 'Pause' : 'Play',
              onPressed: () =>
                  value.isPlaying ? _controller.pause() : _controller.play(),
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ],
      );
    },
  );
}
