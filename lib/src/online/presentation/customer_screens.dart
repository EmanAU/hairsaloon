import 'package:flutter/material.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';
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
    child: ListTile(
      title: Text(salon.name),
      subtitle: Text('${salon.city} · ${salon.area}'),
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

  Widget _serviceTile(SalonService service) => Card(
    child: ListTile(
      title: Text(service.name),
      subtitle: Text(service.category),
      trailing: Text(service.price.toStringAsFixed(2)),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OnlinePage(
            title: service.name,
            children: [
              Text(
                service.price.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                service.description.isEmpty
                    ? 'No description added yet.'
                    : service.description,
              ),
              ServiceMedia(
                repository: widget.repository,
                serviceId: service.id,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: widget.business.name,
    children: [
      Text(widget.business.address),
      if (widget.barberId != null)
        FutureBuilder<String?>(
          future: widget.repository.profilePhoto(barberId: widget.barberId),
          builder: (context, snapshot) => snapshot.data == null
              ? const SizedBox.shrink()
              : Image.network(
                  snapshot.data!,
                  height: 150,
                  errorBuilder: (_, error, stack) => const Icon(Icons.person),
                ),
        ),
      Text('${widget.business.city} · ${widget.business.area}'),
      PublicQr(
        destination: QrDestination(
          widget.barberId == null ? 'salon' : 'barber',
          widget.barberId ?? widget.business.id,
        ),
        label: widget.barberId == null ? 'Salon QR' : 'Barber QR',
      ),
      const SizedBox(height: 24),
      Text('Barbers', style: Theme.of(context).textTheme.titleLarge),
      RemoteContent<List<SalonStaff>>(
        future: _staff,
        onRetry: () => setState(
          () => _staff = widget.repository.staff(widget.business.id),
        ),
        builder: (staff) => Column(
          children: [
            if (staff.isEmpty) const Text('No active barbers listed yet.'),
            for (final barber in staff.where(
              (b) => widget.barberId == null || b.id == widget.barberId,
            ))
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(barber.name),
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
                            business: widget.business,
                            barberId: barber.id,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('Services', style: Theme.of(context).textTheme.titleLarge),
      RemoteContent<List<SalonService>>(
        future: _services,
        onRetry: () => setState(
          () => _services = widget.repository.services(widget.business.id),
        ),
        builder: (services) => services.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No services published yet.'),
              )
            : Column(children: services.map(_serviceTile).toList()),
      ),
      ReviewsPanel(
        repository: widget.repository,
        businessId: widget.business.id,
        employeeId: widget.barberId,
      ),
    ],
  );
}
