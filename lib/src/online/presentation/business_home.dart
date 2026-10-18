import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'business_form.dart';
import 'business_approval.dart';
import 'profile_form.dart';
import 'online_session.dart';
import 'rate_list_screen.dart';
import 'contracts_screen.dart';
import 'staff_screen.dart';
import 'widgets/online_widgets.dart';
import 'widgets/workspace_card.dart';
import 'widgets/business_photo.dart';
import 'qr_screen.dart';
import 'workspace_screen.dart';
import '../domain/qr_destination.dart';

class BusinessHome extends StatelessWidget {
  const BusinessHome({
    super.key,
    required this.session,
    required this.onSignOut,
    required this.onOpenOffline,
  });
  final OnlineSession session;
  final Future<void> Function() onSignOut;
  final VoidCallback onOpenOffline;

  Future<void> _edit(BuildContext context, Widget page) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (saved == true) await session.reload();
  }

  Future<void> _startBusiness(BuildContext context) async {
    final navigator = Navigator.of(context);
    final existing = session.workspace!.businesses.map((b) => b.id).toSet();
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessForm(repository: session.repository),
      ),
    );
    await session.reload();
    if (saved != true) return;
    if (!navigator.mounted) return;
    final created = session.workspace?.businesses.where(
      (b) => !existing.contains(b.id),
    );
    if (created != null && created.isNotEmpty) {
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => OwnerBusiness(
            repository: session.repository,
            businessId: created.first.id,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = session.workspace!;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        title: const Text(
          'Your workspace',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit personal profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => _edit(
              context,
              ProfileForm(
                repository: session.repository,
                profile: workspace.profile,
                name: workspace.account.name,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh account',
            onPressed: session.reload,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) async {
              if (value == 'offline') {
                onOpenOffline();
              } else {
                await onSignOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'offline',
                child: Text('Open offline business app'),
              ),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (workspace.isCached)
                const Text(
                  'Offline: showing saved account details. Approval and contract changes require a connection.',
                ),
              if (workspace.businesses.isNotEmpty) ...[
                const Text(
                  'Your businesses',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                WorkspaceCards(
                  children: [
                    for (final business in workspace.businesses)
                      WorkspaceCard(
                        title: business.name,
                        leading: BusinessPhoto(
                          repository: session.repository,
                          business: business,
                        ),
                        subtitle: business.isActive
                            ? 'Active · ${business.city}'
                            : 'Awaiting approval · ${business.city}',
                        icon: Icons.storefront_outlined,
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OwnerBusiness(
                              repository: session.repository,
                              businessId: business.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              WorkspaceCards(
                children: [
                  WorkspaceCard(
                    title: 'Start a business',
                    subtitle: 'Set up your salon and manage your team.',
                    icon: Icons.storefront_outlined,
                    onTap: () => _startBusiness(context),
                  ),
                  WorkspaceCard(
                    title: 'Join a salon',
                    subtitle: 'Join as an employee with a salon code or QR.',
                    icon: Icons.group_add_outlined,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            JoinSalon(repository: session.repository),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerBusiness extends StatefulWidget {
  const OwnerBusiness({
    super.key,
    required this.repository,
    required this.businessId,
  });
  final OnlineRepository repository;
  final String businessId;

  @override
  State<OwnerBusiness> createState() => _OwnerBusinessState();
}

class _OwnerBusinessState extends State<OwnerBusiness> {
  late Future<OnlineWorkspace> _workspace = widget.repository.loadWorkspace();
  Future<String>? _invite;
  Future<List<SalonStaff>>? _team;
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _team != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _team = widget.repository.team(widget.businessId));
      }
    });
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  void _refresh() => setState(() {
    _workspace = widget.repository.loadWorkspace();
    _invite = null;
    _team = null;
  });

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Business details',
    actions: [
      IconButton(
        onPressed: _refresh,
        tooltip: 'Refresh business',
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      RemoteContent(
        future: _workspace,
        onRetry: _refresh,
        builder: (workspace) {
          final matches = workspace.businesses.where(
            (business) => business.id == widget.businessId,
          );
          if (matches.isEmpty) {
            return const Text(
              'This business is no longer available to your account.',
            );
          }
          final business = matches.first;
          if (!business.isActive) {
            return BusinessApproval(
              business: business,
              repository: widget.repository,
              onRefresh: _refresh,
              onEdit: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessForm(
                      repository: widget.repository,
                      business: business,
                    ),
                  ),
                );
                if (saved == true && mounted) _refresh();
              },
            );
          }
          _team ??= widget.repository.team(business.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (business.logoPath != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: BusinessPhoto(
                    repository: widget.repository,
                    business: business,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                business.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(business.address),
              Text('${business.city} · ${business.area}'),
              Text(business.phone),
              const SizedBox(height: 20),
              Text(
                business.isActive
                    ? 'Approved and visible to customers.'
                    : 'This business is inactive. Admin approval is required before customers can find it or employees can join.',
              ),
              const SizedBox(height: 20),
              WorkspaceCards(
                children: [
                  WorkspaceCard(
                    title: 'Employees & contracts',
                    subtitle: 'Join requests, employees and agreements.',
                    leading: FutureBuilder<List<SalonStaff>>(
                      future: _team,
                      builder: (context, snapshot) {
                        final count =
                            snapshot.data
                                ?.where((e) => e.joinStatus == 'pending')
                                .length ??
                            0;
                        return Badge(
                          label: Text('$count'),
                          isLabelVisible: count > 0,
                          child: const Icon(
                            Icons.people_outline,
                            size: 30,
                            color: Color(0xFF34441D),
                          ),
                        );
                      },
                    ),
                    icon: Icons.people_outline,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffScreen(
                          repository: widget.repository,
                          businessId: business.id,
                        ),
                      ),
                    ),
                  ),
                  WorkspaceCard(
                    title: 'Business details',
                    subtitle: 'Update your salon information.',
                    icon: Icons.edit_outlined,
                    onTap: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessForm(
                            repository: widget.repository,
                            business: business,
                          ),
                        ),
                      );
                      if (saved == true && mounted) _refresh();
                    },
                  ),
                  WorkspaceCard(
                    title: 'Services & prices',
                    subtitle: 'Manage your rate list and service photos.',
                    icon: Icons.list_alt,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlineRateList(
                            repository: widget.repository,
                            businessId: business.id,
                          ),
                        ),
                      );
                    },
                  ),
                  WorkspaceCard(
                    title: 'Billing workspace',
                    subtitle: 'Open your salon’s online and offline workspace.',
                    icon: Icons.sync,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkspaceScreen(
                            repository: widget.repository,
                            business: business,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (business.isActive) ...[
                PublicQr(
                  destination: QrDestination('salon', business.id),
                  label: 'Customer salon QR',
                ),
                ActionButton(
                  label: 'Show employee joining code',
                  icon: Icons.group_add_outlined,
                  onPressed: () async {
                    setState(
                      () => _invite = widget.repository.businessInvite(
                        business.id,
                      ),
                    );
                  },
                ),
                if (_invite != null)
                  RemoteContent(
                    future: _invite!,
                    onRetry: () => setState(
                      () => _invite = widget.repository.businessInvite(
                        business.id,
                      ),
                    ),
                    builder: (code) => Column(
                      children: [
                        CopyCode(code: code, label: 'Salon joining code'),
                        PublicQr(
                          destination: QrDestination('join', code),
                          label: 'Employee invitation QR',
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class JoinSalon extends StatefulWidget {
  const JoinSalon({super.key, required this.repository, this.initialCode});
  final OnlineRepository repository;
  final String? initialCode;

  @override
  State<JoinSalon> createState() => _JoinSalonState();
}

class _JoinSalonState extends State<JoinSalon> {
  late final _code = TextEditingController(text: widget.initialCode);
  final _form = GlobalKey<FormState>();
  bool _requested = false;
  bool _requesting = false;
  late Future<List<SalonJoinRequest>> _joinRequests = widget.repository
      .joinRequests();
  late final Timer _poll;
  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          !_requesting &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _joinRequests = widget.repository.joinRequests());
      }
    });
  }

  Future<void> _request() async {
    if (_requesting || !_form.currentState!.validate()) return;
    setState(() => _requesting = true);
    try {
      await widget.repository.requestJoin(_code.text.trim());
      if (mounted) {
        setState(() {
          _requested = true;
          _joinRequests = widget.repository.joinRequests();
        });
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _contracts() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ContractsScreen(repository: widget.repository),
    ),
  );

  Future<void> _scan() async {
    final target = await Navigator.push<QrDestination>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQr(joining: true)),
    );
    if (target != null && mounted) _code.text = target.id;
  }

  @override
  void dispose() {
    _poll.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_requesting,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Join a salon',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          IconButton(
            tooltip: 'My contracts',
            icon: const Icon(Icons.description_outlined),
            onPressed: _requesting ? null : _contracts,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              if (_requested)
                Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: Color(0xFF668400),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Request sent',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Waiting for the salon owner’s approval.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF718094)),
                    ),
                    const SizedBox(height: 24),
                    ActionButton(
                      label: 'View my contracts',
                      onPressed: () async => _contracts(),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.group_add_outlined,
                        size: 48,
                        color: Color(0xFF34441D),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter your salon’s code or scan its QR.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF718094)),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requesting ? null : _scan,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan salon QR'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(color: Color(0xFF718094)),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: _code,
                        enabled: !_requesting,
                        decoration: InputDecoration(
                          labelText: 'Salon joining code',
                          hintText: 'Paste salon code',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E5EA),
                            ),
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Paste code',
                            icon: const Icon(Icons.content_paste, size: 20),
                            onPressed: _requesting
                                ? null
                                : () async {
                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    if (mounted && data?.text != null) {
                                      _code.text = data!.text!.trim();
                                    }
                                  },
                          ),
                        ),
                        autocorrect: false,
                        validator: (value) =>
                            RegExp(
                              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                            ).hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Paste a valid salon code',
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton(
                          label: 'Request to join',
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _request,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _requestHistory(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _requestHistory() => FutureBuilder<List<SalonJoinRequest>>(
    future: _joinRequests,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () =>
              setState(() => _joinRequests = widget.repository.joinRequests()),
          child: const Text('Retry join request status'),
        );
      }
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My join requests',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final request in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(request.businessName),
              subtitle: Text(switch (request.status) {
                'accepted' => 'Joined · view your contracts',
                'declined' => 'Request declined',
                _ => 'Waiting for owner approval',
              }),
              trailing: Icon(
                request.status == 'accepted'
                    ? Icons.check_circle_outline
                    : request.status == 'declined'
                    ? Icons.close
                    : Icons.schedule,
                size: 22,
              ),
              onTap: request.status == 'accepted' ? _contracts : null,
            ),
        ],
      );
    },
  );
}
