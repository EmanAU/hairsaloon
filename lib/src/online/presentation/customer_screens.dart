import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';
import 'widgets/business_photo.dart';
import 'widgets/before_after_slider.dart';
import 'widgets/service_rich_content.dart';
import 'qr_screen.dart';
import 'reviews_panel.dart';
import '../domain/qr_destination.dart';

class CustomerDirectory extends StatefulWidget {
  const CustomerDirectory({
    super.key,
    required this.repository,
    required this.onSignOut,
  });
  final OnlineRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<CustomerDirectory> createState() => _CustomerDirectoryState();
}

class _CustomerDirectoryState extends State<CustomerDirectory> {
  late Future<List<SalonBusiness>> _businesses = widget.repository
      .discoverBusinesses();
  String _search = '';
  int _page = 0;

  void _load() => setState(
    () => _businesses = widget.repository.discoverBusinesses(
      search: _search,
      page: _page,
    ),
  );

  Widget _salonTile(SalonBusiness salon) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: BusinessPhoto(
          repository: widget.repository,
          business: salon,
        ),
        title: Text(salon.name, style: text.titleSmall),
        subtitle: Text(
          '${salon.type}\n${salon.city} · ${salon.area}',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        isThreeLine: true,
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.iconMuted,
        ),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SalonDetails(repository: widget.repository, business: salon),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OnlinePage(
      title: 'Find a salon',
      actions: [
        IconButton(
          tooltip: 'Scan salon or barber QR',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            final target = await Navigator.push<QrDestination>(
              context,
              MaterialPageRoute(builder: (_) => const ScanQr()),
            );
            if (target == null || !mounted) return;
            try {
              final business = await widget.repository.findBusiness(
                target.id,
                barber: target.kind == 'barber',
              );
              if (!context.mounted) return;
              if (business == null) {
                showMessage(
                  context,
                  'This salon or barber is not currently available.',
                );
                return;
              }
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SalonDetails(
                    repository: widget.repository,
                    business: business,
                    barberId: target.kind == 'barber' ? target.id : null,
                  ),
                ),
              );
            } catch (_) {
              if (context.mounted) {
                showMessage(
                  context,
                  'Could not open QR. Check your connection and try again.',
                );
              }
            }
          },
        ),
        IconButton(
          tooltip: 'Refresh salons',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Search salon name',
            prefixIcon: const Icon(Icons.search),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _search = value.trim();
            _page = 0;
            _load();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        RemoteContent<List<SalonBusiness>>(
          future: _businesses,
          onRetry: _load,
          builder: (businesses) => Column(
            children: [
              if (businesses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No salons found. Try another search or check back later.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...businesses.map(_salonTile),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _page == 0
                        ? null
                        : () {
                            _page--;
                            _load();
                          },
                    child: const Text('Previous'),
                  ),
                  Text('Page ${_page + 1}', style: text.bodyMedium),
                  TextButton(
                    onPressed: businesses.length < 25
                        ? null
                        : () {
                            _page++;
                            _load();
                          },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton(
            onPressed: widget.onSignOut,
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class SalonDetails extends StatefulWidget {
  const SalonDetails({
    super.key,
    required this.repository,
    required this.business,
    this.barberId,
  });
  final OnlineRepository repository;
  final SalonBusiness business;
  final String? barberId;

  @override
  State<SalonDetails> createState() => _SalonDetailsState();
}

class _SalonDetailsState extends State<SalonDetails> {
  late Future<List<SalonStaff>> _staff = widget.repository.staff(
    widget.business.id,
  );
  late Future<List<SalonService>> _services = widget.repository.services(
    widget.business.id,
  );

  void _openService(SalonService service) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailPage(
          repository: widget.repository,
          business: widget.business,
          service: service,
        ),
      ),
    );
  }

  Map<String, List<SalonService>> _group(List<SalonService> services) {
    final groups = <String, List<SalonService>>{};
    for (final service in services) {
      final key = service.category.trim().isEmpty
          ? 'General'
          : service.category.trim();
      groups.putIfAbsent(key, () => []).add(service);
    }
    final keys = groups.keys.toList()..sort();
    return {for (final key in keys) key: groups[key]!};
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        title: Text(business.name, style: text.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _staff = widget.repository.staff(business.id);
              _services = widget.repository.services(business.id);
            }),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.homeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: ColoredBox(
                              color: AppColors.homeSage,
                              child: Center(
                                child: BusinessPhoto(
                                  repository: widget.repository,
                                  business: business,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(business.name, style: text.headlineSmall),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                business.type,
                                style: text.labelLarge?.copyWith(
                                  color: AppColors.homeOlive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(
                      icon: Icons.place_outlined,
                      text: [
                        business.address,
                        '${business.area}, ${business.city}',
                      ].where((s) => s.trim().isNotEmpty).join('\n'),
                    ),
                    if (business.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        text: business.phone,
                      ),
                    ],
                    if (widget.barberId != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FutureBuilder<String?>(
                        future: widget.repository.profilePhoto(
                          barberId: widget.barberId,
                        ),
                        builder: (context, snapshot) {
                          final url = snapshot.data;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.homeSage,
                                backgroundImage: url == null
                                    ? null
                                    : NetworkImage(url),
                                child: url == null
                                    ? const Icon(Icons.person_outline)
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Barber profile from QR',
                                  style: text.titleSmall,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Rate list', style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap a service for details, photos and price.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              RemoteContent<List<SalonService>>(
                future: _services,
                onRetry: () => setState(
                  () => _services = widget.repository.services(business.id),
                ),
                builder: (services) {
                  if (services.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        'No services published yet.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  final groups = _group(services);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom: AppSpacing.xs,
                          ),
                          child: Text(entry.key, style: text.titleSmall),
                        ),
                        for (final service in entry.value)
                          _ServiceRow(
                            name: service.name,
                            description: service.description.trim().isEmpty
                                ? 'View details'
                                : service.description,
                            price:
                                'Rs ${service.price.toStringAsFixed(0)}',
                            onTap: () => _openService(service),
                          ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Barbers', style: text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RemoteContent<List<SalonStaff>>(
                future: _staff,
                onRetry: () => setState(
                  () => _staff = widget.repository.staff(business.id),
                ),
                builder: (staff) {
                  final visible = staff
                      .where(
                        (b) =>
                            widget.barberId == null || b.id == widget.barberId,
                      )
                      .toList();
                  if (visible.isEmpty) {
                    return Text(
                      'No active barbers listed yet.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final barber in visible)
                        _BarberRow(
                          name: barber.name,
                          subtitle: barber.isWorking
                              ? 'Available now'
                              : 'Listed at this salon',
                          showChevron: widget.barberId == null,
                          onTap: widget.barberId != null
                              ? null
                              : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SalonDetails(
                                      repository: widget.repository,
                                      business: business,
                                      barberId: barber.id,
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ReviewsPanel(
                repository: widget.repository,
                businessId: business.id,
                employeeId: widget.barberId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  late final Future<List<Map<String, dynamic>>> _media = widget.repository
      .media(widget.service.id);

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
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        title: Text(service.name, style: text.titleLarge),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Text(
                widget.business.name,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(service.name, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                service.category.trim().isEmpty ? 'Service' : service.category,
                style: text.labelLarge?.copyWith(color: AppColors.homeOlive),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Rs ${service.price.toStringAsFixed(0)}',
                style: text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              ServiceRichContent(
                contentJson: service.contentJson,
                fallbackDescription: service.description,
              ),
              const SizedBox(height: AppSpacing.lg),
              FutureBuilder<List<Map<String, dynamic>>>(
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
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        'Could not load photos. Pull back and try again.',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                  final pair = _pair(rows);
                  if (pair.before != null && pair.after != null) {
                    return BeforeAfterSlider(
                      beforeUrl: pair.before!,
                      afterUrl: pair.after!,
                    );
                  }
                  if (rows.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Photos for this service are not ready yet.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.description,
    required this.price,
    required this.onTap,
  });
  final String name;
  final String description;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.homeBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: text.titleSmall),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarberRow extends StatelessWidget {
  const _BarberRow({
    required this.name,
    required this.subtitle,
    required this.showChevron,
    this.onTap,
  });
  final String name;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.homeBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.homeSage,
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.titleSmall),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showChevron)
                  const Icon(Icons.chevron_right, color: AppColors.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.iconMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: style?.copyWith(
              height: 1.35,
              color: AppColors.homeInk,
            ),
          ),
        ),
      ],
    );
  }
}
