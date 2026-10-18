import 'package:flutter/material.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'business_form.dart';
import 'profile_form.dart';
import 'online_session.dart';
import 'rate_list_screen.dart';
import 'contracts_screen.dart';
import 'staff_screen.dart';
import 'widgets/online_widgets.dart';
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
    if (session.workspace!.profile == null) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileForm(repository: session.repository),
        ),
      );
      if (saved != true || !context.mounted) return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessForm(repository: session.repository),
      ),
    );
    await session.reload();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = session.workspace!;
    return OnlinePage(
      title: 'Welcome, ${workspace.account.name}',
      actions: [
        IconButton(
          tooltip: 'Refresh account',
          onPressed: session.reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        if (workspace.isCached)
          const Text(
            'Offline: showing saved account details. Approval and contract changes require a connection.',
          ),
        Text(
          'Business or personal profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Register your salon, or create your barber profile to join a salon.',
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: workspace.profile == null
              ? 'Create personal profile'
              : 'Edit personal profile',
          icon: Icons.person_outline,
          onPressed: () => _edit(
            context,
            ProfileForm(
              repository: session.repository,
              profile: workspace.profile,
            ),
          ),
        ),
        if (workspace.profile != null) ...[
          CopyCode(
            code: workspace.profile!.code,
            label: 'Your permanent profile code',
          ),
          ActionButton(
            label: 'My contracts',
            icon: Icons.description_outlined,
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ContractsScreen(repository: session.repository),
                ),
              );
            },
          ),
          ActionButton(
            label: 'Join a salon by code',
            icon: Icons.group_add_outlined,
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => JoinSalon(repository: session.repository),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        Text('Your businesses', style: Theme.of(context).textTheme.titleLarge),
        for (final business in workspace.businesses)
          Card(
            child: ListTile(
              title: Text(business.name),
              subtitle: Text(
                business.isActive
                    ? 'Active · ${business.city}'
                    : 'Inactive · awaiting admin approval',
              ),
              trailing: const Icon(Icons.chevron_right),
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
          ),
        ActionButton(
          label: 'Start a business',
          icon: Icons.storefront_outlined,
          onPressed: () => _startBusiness(context),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onOpenOffline,
          icon: const Icon(Icons.offline_bolt_outlined),
          label: const Text('Open offline business app'),
        ),
        ActionButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: onSignOut,
        ),
      ],
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

  void _refresh() => setState(() {
    _workspace = widget.repository.loadWorkspace();
    _invite = null;
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              ActionButton(
                label: 'Edit business details',
                icon: Icons.edit_outlined,
                onPressed: () async {
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
              ActionButton(
                label: 'Manage online rate list',
                icon: Icons.list_alt,
                onPressed: () async {
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
              ActionButton(
                label: 'Offline / online business workspace',
                icon: Icons.sync,
                onPressed: () async {
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
              ActionButton(
                label: 'Employees & contracts',
                icon: Icons.people_outline,
                onPressed: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffScreen(
                        repository: widget.repository,
                        businessId: business.id,
                      ),
                    ),
                  );
                },
              ),
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

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Join a salon',
    children: [
      const Text(
        'Ask the salon owner for their joining code. Joining creates a request; employment starts only after you accept a contract.',
      ),
      const SizedBox(height: 20),
      if (_requested)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Request sent. The salon owner can now propose your contract.',
            ),
          ),
        )
      else
        Form(
          key: _form,
          child: Column(
            children: [
              ActionButton(
                label: 'Scan employee invitation QR',
                icon: Icons.qr_code_scanner,
                onPressed: () async {
                  final target = await Navigator.push<QrDestination>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanQr(joining: true),
                    ),
                  );
                  if (target != null && mounted) _code.text = target.id;
                },
              ),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Salon joining code',
                ),
                autocorrect: false,
                validator: (value) =>
                    RegExp(
                      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Paste a valid salon code',
              ),
              ActionButton(
                label: 'Request to join',
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  await widget.repository.requestJoin(_code.text);
                  if (mounted) setState(() => _requested = true);
                },
              ),
            ],
          ),
        ),
    ],
  );
}
