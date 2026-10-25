import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/utils/pk_phone.dart';
import '../../theme/app_colors.dart';
import '../data/customer_history.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import '../domain/qr_destination.dart';
import 'customer_service_details.dart';
import 'qr_screen.dart';
import 'reviews_panel.dart';
import 'widgets/online_widgets.dart';
import 'widgets/business_photo.dart';

const _ink = Color(0xFF17251E),
    _line = Color(0xFFEBEDE9),
    _soft = Color(0xFFF7F8F5);

class CustomerDirectory extends StatefulWidget {
  const CustomerDirectory({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.scanDestination,
  });
  final OnlineRepository repository;
  final Future<void> Function() onSignOut;
  final Future<QrDestination?> Function(BuildContext)? scanDestination;
  @override
  State<CustomerDirectory> createState() => _CustomerDirectoryState();
}

class _CustomerDirectoryState extends State<CustomerDirectory> {
  late final _history = CustomerHistory(widget.repository.userId ?? 'guest');
  late Future<List<ScannedSalon>> _recent = _history.load();
  bool _opening = false, _scanning = false;
  void _load() => setState(() {
    _recent = _history.load();
  });
  Future<void> _open(
    SalonBusiness salon, {
    String? barberId,
    bool scanned = false,
  }) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final current = scanned
          ? salon
          : await widget.repository.findBusiness(salon.id);
      if (!mounted) return;
      if (current == null || !current.isActive) {
        showMessage(context, 'This salon is not currently available.');
        return;
      }
      if (scanned) {
        try {
          await _history.record(current);
        } catch (_) {
          /* Local storage must not prevent salon access. */
        }
      }
      if (!mounted) return;
      setState(() {
        _recent = _history.load();
      });
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SalonDetails(
            repository: widget.repository,
            business: current,
            barberId: barberId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not open this salon. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _scanQr() async {
    if (_opening || _scanning) return;
    _scanning = true;
    try {
      final QrDestination? target;
      final scanner = widget.scanDestination;
      if (scanner != null) {
        target = await scanner(context);
      } else {
        target = await Navigator.push<QrDestination>(
          context,
          MaterialPageRoute(builder: (_) => const ScanQr()),
        );
      }
      if (target == null || !mounted) return;
      final salon = await widget.repository.findBusiness(
        target.id,
        barber: target.kind == 'barber',
      );
      if (!mounted) return;
      if (salon == null) {
        showMessage(
          context,
          'This salon or barber is not currently available.',
        );
        return;
      }
      await _open(
        salon,
        barberId: target.kind == 'barber' ? target.id : null,
        scanned: true,
      );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not open QR. Check your connection and try again.',
        );
      }
    } finally {
      _scanning = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'TrimMatrix',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w500,
          letterSpacing: -.6,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Customer menu',
          icon: const Icon(CupertinoIcons.ellipsis_circle),
          onSelected: (v) async {
            if (v == 'scan') await _scanQr();
            if (v == 'refresh') _load();
            if (v == 'history') _load();
            if (v == 'signout') await widget.onSignOut();
          },
          itemBuilder: (_) => [
            _menu('scan', 'Scan salon QR', CupertinoIcons.qrcode_viewfinder),
            _menu('history', 'Scanned salons', CupertinoIcons.clock),
            _menu('refresh', 'Refresh', CupertinoIcons.refresh),
            _menu('signout', 'Sign out', CupertinoIcons.square_arrow_right),
          ],
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _load();
        await _recent;
      },
      child: _PageList(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 26),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FFCC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR NEXT GOOD HAIR DAY',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: AppColors.homeOlive,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your salon.\nOne scan away.',
                  style: TextStyle(
                    fontSize: 31,
                    height: 1.12,
                    letterSpacing: -.9,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan the salon’s QR to explore services, see results and share your experience.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _opening ? null : _scanQr,
                    icon: const Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      size: 21,
                    ),
                    label: Text(_opening ? 'Opening salon…' : 'Scan salon QR'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<ScannedSalon>>(
            future: _recent,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snap.hasError) {
                return TextButton(
                  onPressed: _load,
                  child: const Text('Retry scanned salons'),
                );
              }
              final rows = snap.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    'Scanned salons',
                    subtitle: 'QR scans saved on this device',
                  ),
                  if (rows.isEmpty)
                    const _Empty(
                      'Your salons will appear here',
                      'Scan a salon QR and find it here next time.',
                      CupertinoIcons.clock,
                    ),
                  for (final row in rows)
                    _SalonTile(
                      repository: widget.repository,
                      salon: row.business,
                      subtitle:
                          '${row.scans == 1 ? 'Scanned once' : 'Scanned ${row.scans} times'} · ${_date(row.lastScanned)}',
                      onTap: () => _open(row.business),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
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
  late Future<List<SalonService>> _services = widget.repository.services(
    widget.business.id,
  );
  late Future<List<SalonStaff>> _staff = widget.repository.staff(
    widget.business.id,
  );
  late Future<String?> _barberPhoto = widget.barberId == null
      ? Future.value(null)
      : widget.repository.profilePhoto(barberId: widget.barberId);
  final _reviews = GlobalKey<ReviewsPanelState>();
  String _category = 'All', _search = '';
  bool _reviewOpening = false;
  Future<void> _writeReview() async {
    if (_reviewOpening) return;
    _reviewOpening = true;
    try {
      final saved = await showCustomerReviewEditor(
        context,
        widget.repository,
        widget.business.id,
        employeeId: widget.barberId,
      );
      if (saved && mounted) _reviews.currentState?.refresh();
    } finally {
      _reviewOpening = false;
    }
  }

  void _refresh() {
    setState(() {
      _services = widget.repository.services(widget.business.id);
      _staff = widget.repository.staff(widget.business.id);
      if (widget.barberId != null) {
        _barberPhoto = widget.repository.profilePhoto(
          barberId: widget.barberId,
        );
      }
    });
    _reviews.currentState?.refresh();
  }

  Future<void> _information() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionTitle(widget.business.name, subtitle: widget.business.type),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.location),
              title: Text(widget.business.address),
              subtitle: Text(
                '${widget.business.area}, ${widget.business.city}',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.phone),
              title: SelectableText(PkPhone.localNumber(widget.business.phone)),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Meet the team'),
            FutureBuilder<List<SalonStaff>>(
              future: _staff,
              builder: (_, snap) => Column(
                children: [
                  if (snap.hasError)
                    const Text('Team is unavailable. Please try again.'),
                  if (snap.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator(),
                  if (snap.hasData && snap.data!.isEmpty)
                    const Text('No team members listed yet.'),
                  for (final member in snap.data ?? <SalonStaff>[])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: _soft,
                        child: Icon(CupertinoIcons.person, color: _ink),
                      ),
                      title: Text(member.name),
                      subtitle: Text(
                        member.isWorking ? 'Available now' : 'Team member',
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalonDetails(
                              repository: widget.repository,
                              business: widget.business,
                              barberId: member.id,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(CupertinoIcons.back),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text(
        'Your salon',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Salon menu',
          icon: const Icon(CupertinoIcons.ellipsis_circle),
          onSelected: (v) {
            if (v == 'info') _information();
            if (v == 'review') _writeReview();
            if (v == 'refresh') _refresh();
          },
          itemBuilder: (_) => [
            _menu('info', 'Salon details & team', CupertinoIcons.info_circle),
            _menu('review', 'Write or edit review', CupertinoIcons.star),
            _menu('refresh', 'Refresh', CupertinoIcons.refresh),
          ],
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _services;
      },
      child: _PageList(
        top: 0,
        children: [
          _SalonCover(repository: widget.repository, business: widget.business),
          const SizedBox(height: 18),
          Text(
            widget.business.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.business.type} · ${widget.business.area}, ${widget.business.city}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.barberId != null)
            FutureBuilder<List<SalonStaff>>(
              future: _staff,
              builder: (_, snap) {
                final member = snap.data
                    ?.where((m) => m.id == widget.barberId)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      FutureBuilder<String?>(
                        future: _barberPhoto,
                        builder: (_, photo) {
                          const fallback = ColoredBox(
                            color: _soft,
                            child: Icon(
                              CupertinoIcons.person,
                              color: AppColors.homeOlive,
                            ),
                          );
                          return SizedBox(
                            width: 38,
                            height: 38,
                            child: ClipOval(
                              child: photo.data == null
                                  ? fallback
                                  : Image.network(
                                      photo.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, error, stack) =>
                                          fallback,
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reviewing ${member?.name ?? 'the scanned barber'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.homeOlive,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _writeReview(),
                  icon: const Icon(CupertinoIcons.star, size: 17),
                  label: const Text('Write a review'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Salon information',
                onPressed: _information,
                icon: const Icon(CupertinoIcons.info_circle, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            'Services',
            subtitle: 'The salon’s rate list. Tap to see the details.',
          ),
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            decoration: _searchDecoration('Find a service'),
          ),
          const SizedBox(height: 12),
          RemoteContent<List<SalonService>>(
            future: _services,
            onRetry: _refresh,
            builder: (services) {
              final active = services.where((s) => s.isActive).toList();
              final categories = [
                'All',
                ...{
                  for (final s in active)
                    s.category.trim().isEmpty ? 'General' : s.category.trim(),
                },
              ];
              final selected = categories.contains(_category)
                  ? _category
                  : 'All';
              final visible = active
                  .where(
                    (s) =>
                        (selected == 'All' ||
                            (s.category.trim().isEmpty
                                    ? 'General'
                                    : s.category.trim()) ==
                                selected) &&
                        '${s.name} ${s.category}'.toLowerCase().contains(
                          _search,
                        ),
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: selected == c,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: _line),
                              onSelected: (_) => setState(() => _category = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const _Empty(
                      'No services here yet',
                      'Try another category or check back soon.',
                      CupertinoIcons.list_bullet,
                    ),
                  for (final s in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              s.category.isEmpty ? 'General' : s.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rs ${s.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: AppColors.iconMuted,
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailPage(
                                repository: widget.repository,
                                business: widget.business,
                                service: s,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          ReviewsPanel(
            key: _reviews,
            repository: widget.repository,
            businessId: widget.business.id,
            employeeId: widget.barberId,
            showWriteAction: false,
          ),
        ],
      ),
    ),
  );
}

class _SalonCover extends StatelessWidget {
  const _SalonCover({required this.repository, required this.business});
  final OnlineRepository repository;
  final SalonBusiness business;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 185,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 142,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(22),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFEBF8BC)),
                if (business.logoPath != null)
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                    child: BusinessPhoto(
                      placeholderIcon: CupertinoIcons.building_2_fill,
                      repository: repository,
                      business: business,
                      width: double.infinity,
                      height: 142,
                      borderRadius: 0,
                    ),
                  ),
                const ColoredBox(color: Color(0x77E9FFAD)),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 18,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
            ),
            child: BusinessPhoto(
              placeholderIcon: CupertinoIcons.building_2_fill,
              repository: repository,
              business: business,
              width: 88,
              height: 88,
              borderRadius: 23,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SalonTile extends StatelessWidget {
  const _SalonTile({
    required this.repository,
    required this.salon,
    required this.subtitle,
    required this.onTap,
  });
  final OnlineRepository repository;
  final SalonBusiness salon;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: BusinessPhoto(
          placeholderIcon: CupertinoIcons.building_2_fill,
          repository: repository,
          business: salon,
          width: 54,
          height: 54,
          borderRadius: 12,
        ),
        title: Text(
          salon.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 15,
          color: AppColors.iconMuted,
        ),
      ),
    ),
  );
}

class _PageList extends StatelessWidget {
  const _PageList({required this.children, this.top = 16});
  final List<Widget> children;
  final double top;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          top,
          20,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: children,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -.35,
            color: _ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.description, this.icon);
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 28, color: AppColors.homeOlive),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 7),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

InputDecoration _searchDecoration(String hint) => InputDecoration(
  hintText: hint,
  prefixIcon: const Icon(CupertinoIcons.search, size: 19),
  filled: true,
  fillColor: _soft,
  border: const OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
);
PopupMenuItem<String> _menu(String value, String label, IconData icon) =>
    PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: _ink),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
