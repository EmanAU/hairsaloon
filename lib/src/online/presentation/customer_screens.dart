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
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _page = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() => setState(
    () => _businesses = widget.repository.discoverBusinesses(
      search: _search,
      page: _page,
    ),
  );

  Future<void> _scanQr() async {
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
      if (!mounted) return;
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
      if (mounted) {
        showMessage(
          context,
          'Could not open QR. Check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OnlineShell.pageMaxWidth,
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'TrimMatrix',
                                style: text.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  color: AppColors.homeInk,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Scan QR',
                              onPressed: _scanQr,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                            ),
                            IconButton(
                              tooltip: 'Refresh',
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'signout') {
                                  await widget.onSignOut();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'signout',
                                  child: Text('Sign out'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Find your next look',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.homeOlive,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discover salons near you — pick a service, see real results.',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.homeBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (value) {
                              _search = value.trim();
                              _page = 0;
                              _load();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search salon name',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.iconMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                onPressed: () {
                                  _search = _searchCtrl.text.trim();
                                  _page = 0;
                                  _load();
                                },
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Salons',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: RemoteContent<List<SalonBusiness>>(
                      future: _businesses,
                      onRetry: _load,
                      builder: (businesses) {
                        if (businesses.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Text(
                              'No salons found. Try another search.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final salon in businesses)
                              _SalonDiscoverCard(
                                repository: widget.repository,
                                salon: salon,
                                onTap: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SalonDetails(
                                      repository: widget.repository,
                                      business: salon,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
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
                                Text(
                                  'Page ${_page + 1}',
                                  style: text.bodyMedium,
                                ),
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
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SalonDiscoverCard extends StatelessWidget {
  const _SalonDiscoverCard({
    required this.repository,
    required this.salon,
    required this.onTap,
  });

  final OnlineRepository repository;
  final SalonBusiness salon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.homeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 148,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BusinessPhoto(
                        repository: repository,
                        business: salon,
                        width: double.infinity,
                        height: 148,
                        borderRadius: 0,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x66000000),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Text(
                          salon.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              salon.type.trim().isEmpty
                                  ? 'Salon'
                                  : salon.type,
                              style: text.labelLarge?.copyWith(
                                color: AppColors.homeOlive,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                salon.area,
                                salon.city,
                              ].where((s) => s.trim().isNotEmpty).join(' · '),
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _heroOverlay(BuildContext context, SalonBusiness business) {
    final text = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        BusinessPhoto(
          repository: widget.repository,
          business: business,
          width: double.infinity,
          height: double.infinity,
          borderRadius: 0,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xB3000000)],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                business.name,
                style: text.headlineMedium?.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                business.type.trim().isEmpty ? 'Salon' : business.type,
                style: text.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsColumn(BuildContext context, SalonBusiness business) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                      _InfoBlock(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: Icons.place_outlined,
                              text: [
                                business.address,
                                '${business.area}, ${business.city}',
                              ].where((s) => s.trim().isNotEmpty).join('\n'),
                            ),
                            if (business.phone.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.phone_outlined,
                                text: business.phone,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.barberId != null) ...[
                        const SizedBox(height: 14),
                        FutureBuilder<String?>(
                          future: widget.repository.profilePhoto(
                            barberId: widget.barberId,
                          ),
                          builder: (context, snapshot) {
                            final url = snapshot.data;
                            return _InfoBlock(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.homeSage,
                                    backgroundImage: url == null
                                        ? null
                                        : NetworkImage(url),
                                    child: url == null
                                        ? const Icon(Icons.person_outline)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Barber from your QR scan',
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Services',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap any service for details, price and photos.',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RemoteContent<List<SalonService>>(
                        future: _services,
                        onRetry: () => setState(
                          () => _services =
                              widget.repository.services(business.id),
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
                                    top: 10,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.homeOlive,
                                    ),
                                  ),
                                ),
                                for (final service in entry.value)
                                  _ServiceRow(
                                    name: service.name,
                                    description:
                                        service.description.trim().isEmpty
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
                      const SizedBox(height: 24),
                      Text(
                        'Team',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RemoteContent<List<SalonStaff>>(
                        future: _staff,
                        onRetry: () => setState(
                          () =>
                              _staff = widget.repository.staff(business.id),
                        ),
                        builder: (staff) {
                          final visible = staff
                              .where(
                                (b) =>
                                    widget.barberId == null ||
                                    b.id == widget.barberId,
                              )
                              .toList();
                          if (visible.isEmpty) {
                            return Text(
                              'No team members listed yet.',
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
                                      : 'At this salon',
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
          const SizedBox(height: 28),
          Text(
            'Reviews',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ReviewsPanel(
            repository: widget.repository,
            businessId: business.id,
            employeeId: widget.barberId,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _heroOverlay(context, business),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 4,
                        left: 8,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface.withValues(
                              alpha: 0.9,
                            ),
                          ),
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 4,
                        right: 8,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface.withValues(
                              alpha: 0.9,
                            ),
                          ),
                          tooltip: 'Refresh',
                          onPressed: () => setState(() {
                            _staff = widget.repository.staff(business.id);
                            _services =
                                widget.repository.services(business.id);
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: ColoredBox(
                    color: AppColors.homeCanvas,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [_detailsColumn(context, business)],
                    ),
                  ),
                ),
              ],
            );
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppColors.homeCanvas,
                foregroundColor: AppColors.homeInk,
                flexibleSpace: FlexibleSpaceBar(
                  background: _heroOverlay(context, business),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => setState(() {
                      _staff = widget.repository.staff(business.id);
                      _services = widget.repository.services(business.id);
                    }),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: OnlineShell.pageMaxWidth,
                    ),
                    child: _detailsColumn(context, business),
                  ),
                ),
              ),
            ],
          );
        },
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
    final category =
        service.category.trim().isEmpty ? 'Service' : service.category;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(
          'Service',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              style: TextStyle(
                fontSize: wide ? 34 : 30,
                fontWeight: FontWeight.w900,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    'From',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
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
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _InfoBlock(
              child: ServiceRichContent(
                contentJson: service.contentJson,
                fallbackDescription: service.description,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    'Could not load photos.',
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before & after',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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
              return const SizedBox.shrink();
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
                  Expanded(
                    child: ListView(children: about),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.homeBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.iconMuted,
                      ),
                    ],
                  ),
                ],
              ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.homeBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.homeSage,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.iconMuted,
                    ),
                ],
              ),
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
              height: 1.4,
              color: AppColors.homeInk,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
