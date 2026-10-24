import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';
import 'widgets/before_after_slider.dart';
import 'widgets/service_rich_content.dart';

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({
    super.key,
    required this.repository,
    required this.business,
    required this.service,
  });
  final OnlineRepository repository;
  final SalonBusiness business;
  final SalonService service;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  late Future<List<Map<String, dynamic>>> _media = widget.repository.media(
    widget.service.id,
  );

  SalonService get service => widget.service;

  ({String? before, String? after}) _pair(List<Map<String, dynamic>> rows) {
    final pairs = <String, Map<String, String>>{};
    for (final row in rows) {
      final kind = row['kind'] as String?;
      final url = row['url'] as String?;
      if (url == null || (kind != 'before' && kind != 'after')) continue;
      final pairId = (row['pair_id'] as String?) ?? '_';
      pairs.putIfAbsent(pairId, () => <String, String>{})[kind!] = url;
    }
    for (final entry in pairs.entries) {
      final before = entry.value['before'];
      final after = entry.value['after'];
      if (before != null && after != null) {
        return (before: before, after: after);
      }
    }
    return (before: null, after: null);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final category = service.category.trim().isEmpty
        ? 'Service'
        : service.category;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Service details',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final header = <Widget>[
            Text(
              widget.business.name.toUpperCase(),
              style: text.labelMedium?.copyWith(
                color: AppColors.homeOlive,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              style: TextStyle(
                fontSize: wide ? 34 : 30,
                fontWeight: FontWeight.w600,
                color: AppColors.homeInk,
                height: 1.12,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    'Service price',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ];
          final about = <Widget>[
            Text(
              'About this service',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _InfoBlock(
              child: service.hasRichContent
                  ? ServiceRichContent(
                      contentJson: service.contentJson,
                      fallbackDescription: service.description,
                    )
                  : Text(
                      service.description.trim().isEmpty
                          ? 'Ask the salon for more details about this service.'
                          : service.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.homeOlive,
                      ),
                    ),
            ),
          ];
          final media = FutureBuilder<List<Map<String, dynamic>>>(
            future: _media,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    children: [
                      const Text('Could not load photos.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _media = widget.repository.media(service.id);
                        }),
                        child: const Text('Retry photos'),
                      ),
                    ],
                  ),
                );
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              final pair = _pair(rows);
              if (pair.before != null && pair.after != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before & after',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Slide to compare the real result.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BeforeAfterSlider(
                        beforeUrl: pair.before!,
                        afterUrl: pair.after!,
                      ),
                    ),
                  ],
                );
              }
              final photos = rows.where((r) => r['url'] is String).toList();
              if (photos.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(CupertinoIcons.photo, color: AppColors.homeOlive),
                      SizedBox(height: 10),
                      Text(
                        'Service photos coming soon',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A closer look',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final photo in photos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          photo['url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const SizedBox(
                            height: 160,
                            child: Center(child: Text('Photo unavailable')),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      children: [...header, const SizedBox(height: 28), media],
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(child: ListView(children: about)),
                ],
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OnlineShell.formMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ...header,
                  const SizedBox(height: 22),
                  ...about,
                  const SizedBox(height: 22),
                  media,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
