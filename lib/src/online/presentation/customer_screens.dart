import 'package:flutter/material.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';
import 'widgets/business_photo.dart';
import 'qr_screen.dart';
import 'reviews_panel.dart';
import 'service_media.dart';
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

  Widget _salonTile(SalonBusiness salon) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE3E7EC)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: BusinessPhoto(
        repository: widget.repository,
        business: salon,
      ),
      title: Text(
        salon.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${salon.type}\n${salon.city} · ${salon.area}'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SalonDetails(repository: widget.repository, business: salon),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
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
        decoration: const InputDecoration(
          labelText: 'Search salon name',
          prefixIcon: Icon(Icons.search),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _search = value.trim();
          _page = 0;
          _load();
        },
      ),
      const SizedBox(height: 20),
      RemoteContent<List<SalonBusiness>>(
        future: _businesses,
        onRetry: _load,
        builder: (businesses) => Column(
          children: [
            if (businesses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No salons found. Try another search or check back later.',
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
                Text('Page ${_page + 1}'),
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
      const SizedBox(height: 24),
      ActionButton(
        label: 'Sign out',
        onPressed: widget.onSignOut,
        icon: Icons.logout,
      ),
    ],
  );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        title: Text(
          business.name,
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE3E7EC)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: ColoredBox(
                                color: const Color(0xFFF0F5DE),
                                child: Center(
                                  child: BusinessPhoto(
                                    repository: widget.repository,
                                    business: business,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  business.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  business.type,
                                  style: const TextStyle(
                                    color: Color(0xFF668400),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        text: [
                          business.address,
                          '${business.area}, ${business.city}',
                        ].where((s) => s.trim().isNotEmpty).join('\n'),
                      ),
                      if (business.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          text: business.phone,
                        ),
                      ],
                      if (widget.barberId != null) ...[
                        const SizedBox(height: 14),
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
                                  backgroundColor: const Color(0xFFF0F5DE),
                                  backgroundImage: url == null
                                      ? null
                                      : NetworkImage(url),
                                  child: url == null
                                      ? const Icon(Icons.person_outline)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Barber profile from QR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
              ),
              const SizedBox(height: 22),
              const Text(
                'Rate list',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a service for details, photos and price.',
                style: TextStyle(color: Color(0xFF718094)),
              ),
              const SizedBox(height: 12),
              RemoteContent<List<SalonService>>(
                future: _services,
                onRetry: () => setState(
                  () => _services = widget.repository.services(business.id),
                ),
                builder: (services) {
                  if (services.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No services published yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF718094)),
                      ),
                    );
                  }
                  final groups = _group(services);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34441D),
                            ),
                          ),
                        ),
                        for (final service in entry.value)
                          Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE3E7EC)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              title: Text(
                                service.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                service.description.trim().isEmpty
                                    ? 'View details'
                                    : service.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs ${service.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Color(0xFF718094),
                                  ),
                                ],
                              ),
                              onTap: () => _openService(service),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const Text(
                'Barbers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
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
                    return const Text(
                      'No active barbers listed yet.',
                      style: TextStyle(color: Color(0xFF718094)),
                    );
                  }
                  return Column(
                    children: [
                      for (final barber in visible)
                        Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE3E7EC)),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF0F5DE),
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              barber.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              barber.isWorking
                                  ? 'Available now'
                                  : 'Listed at this salon',
                            ),
                            trailing: widget.barberId == null
                                ? const Icon(Icons.chevron_right)
                                : null,
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
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
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

class ServiceDetailPage extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF7F8FA),
      title: Text(
        service.name,
        style: const TextStyle(fontFamily: 'Roboto'),
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE3E7EC)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: Color(0xFF718094),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.category.trim().isEmpty
                          ? 'Service'
                          : service.category,
                      style: const TextStyle(
                        color: Color(0xFF668400),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Rs ${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      service.description.trim().isEmpty
                          ? 'No description added yet.'
                          : service.description,
                      style: const TextStyle(
                        height: 1.45,
                        color: Color(0xFF34441D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ServiceMedia(repository: repository, serviceId: service.id),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF718094)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(height: 1.35, color: Color(0xFF34441D)),
        ),
      ),
    ],
  );
}
