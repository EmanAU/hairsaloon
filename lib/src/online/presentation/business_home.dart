import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
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

class BusinessHome extends StatefulWidget {
  const BusinessHome({
    super.key,
    required this.session,
    required this.onSignOut,
    required this.onOpenOffline,
  });
  final OnlineSession session;
  final Future<void> Function() onSignOut;
  final VoidCallback onOpenOffline;

  @override
  State<BusinessHome> createState() => _BusinessHomeState();
}

class _BusinessHomeState extends State<BusinessHome> {
  bool _choosingBusiness = false;
  Future<String>? _invite;
  Future<List<SalonStaff>>? _team;
  final _inviteCode = TextEditingController();
  String? _reviewing;
  late final Timer _poll;

  OnlineSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final workspace = session.workspace;
      if (workspace == null) return;
      final pending = workspace.businesses.any((b) => !b.isActive);
      final active = _primaryActive(workspace);
      if (pending && active == null && !_choosingBusiness) {
        unawaited(session.reload());
      }
      if (active != null && _team != null && _reviewing == null) {
        setState(() {
          _team = session.repository.team(active.id);
        });
      }
    });
  }

  @override
  void dispose() {
    _poll.cancel();
    _inviteCode.dispose();
    super.dispose();
  }

  SalonBusiness? _primaryActive(OnlineWorkspace workspace) {
    final active = workspace.businesses.where((b) => b.isActive).toList();
    return active.isEmpty ? null : active.first;
  }

  Future<void> _edit(BuildContext context, Widget page) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (saved == true) await session.reload();
  }

  Future<void> _startBusiness(BuildContext context) async {
    if (session.workspace!.businesses.isNotEmpty) {
      showMessage(
        context,
        'You already have a business. One owner can register one shop.',
        error: true,
      );
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessForm(
          repository: session.repository,
          onRegistered: session.rememberRegisteredBusiness,
        ),
      ),
    );
    if (saved != true) return;
    await session.reload();
    if (!context.mounted) return;
    setState(() {
      _invite = null;
      _team = null;
    });
    if (saved == true) {
      showMessage(
        context,
        'Business saved. It will open on home after admin approval.',
      );
    }
  }

  Future<void> _openSalon(SalonBusiness business) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerBusiness(
          repository: session.repository,
          businessId: business.id,
          onApproved: () async {
            await session.reload();
            if (mounted) {
              setState(() {
                _invite = null;
                _team = null;
              });
            }
          },
        ),
      ),
    );
    if (mounted) await session.reload();
    if (mounted) {
      setState(() {
        _invite = null;
        _team = null;
      });
    }
  }

  Future<void> _review(
    SalonBusiness business,
    SalonStaff employee,
    bool accept,
  ) async {
    if (_reviewing != null) return;
    setState(() => _reviewing = employee.id);
    try {
      await session.repository.reviewJoin(employee.id, accept);
      if (!mounted) return;
      showMessage(
        context,
        accept
            ? 'Request accepted. Open Billing workspace to use them on bills.'
            : 'Request declined',
      );
      setState(() => _team = session.repository.team(business.id));
    } catch (error) {
      if (!mounted) return;
      showMessage(
        context,
        error is OnlineFailure
            ? error.message
            : 'Could not update this request. Try again.',
      );
    } finally {
      if (mounted) setState(() => _reviewing = null);
    }
  }

  Future<void> _inviteByProfile(SalonBusiness business) async {
    final code = _inviteCode.text.trim();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(code)) {
      showMessage(context, 'Paste a valid employee profile code');
      return;
    }
    try {
      await session.repository.inviteEmployee(business.id, code);
      if (!mounted) return;
      _inviteCode.clear();
      showMessage(
        context,
        'Employee added. Open Billing workspace to see them on bills.',
      );
      setState(() => _team = session.repository.team(business.id));
    } catch (error) {
      if (!mounted) return;
      showMessage(
        context,
        error is OnlineFailure
            ? error.message
            : 'Could not add this employee. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = session.workspace!;
    final active = _choosingBusiness ? null : _primaryActive(workspace);
    if (active != null) {
      return WorkspaceScreen(
        repository: session.repository,
        business: active,
        onClose: () => setState(() => _choosingBusiness = true),
      );
    }
    final pendingBusinesses = _choosingBusiness
        ? <SalonBusiness>[]
        : workspace.businesses.where((b) => !b.isActive).toList();
    final singleBusiness =
        !_choosingBusiness && workspace.businesses.length == 1;

    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        title: Text(active?.name ?? 'Your workspace'),
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
            onPressed: () async {
              await session.reload();
              if (!mounted) return;
              setState(() {
                _invite = null;
                _team = null;
              });
            },
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) async {
              switch (value) {
                case 'offline':
                  widget.onOpenOffline();
                case 'start':
                  await _startBusiness(context);
                case 'join':
                  if (!mounted) return;
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JoinSalon(repository: session.repository),
                    ),
                  );
                case 'signout':
                  await widget.onSignOut();
              }
            },
            itemBuilder: (_) => [
              if (singleBusiness)
                const PopupMenuItem(value: 'join', child: Text('Join a salon')),
              const PopupMenuItem(
                value: 'offline',
                child: Text('Open offline business app'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Offline: showing saved account details. Approval and contract changes require a connection.',
                  ),
                ),
              // One business → land straight on that salon's home / approval.
              if (active != null)
                _ActiveSalonHome(
                  business: active,
                  repository: session.repository,
                  invite: _invite,
                  team: _team,
                  inviteCode: _inviteCode,
                  reviewing: _reviewing,
                  onRetryInvite: () => setState(
                    () =>
                        _invite = session.repository.businessInvite(active.id),
                  ),
                  onRetryTeam: () => setState(
                    () => _team = session.repository.team(active.id),
                  ),
                  onReview: (employee, accept) =>
                      _review(active, employee, accept),
                  onInviteByProfile: () => _inviteByProfile(active),
                  onOpenStaff: () =>
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffScreen(
                            repository: session.repository,
                            businessId: active.id,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          setState(
                            () => _team = session.repository.team(active.id),
                          );
                        }
                      }),
                  onEditBusiness: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessForm(
                          repository: session.repository,
                          business: active,
                        ),
                      ),
                    );
                    if (saved == true) await session.reload();
                    if (mounted) setState(() {});
                  },
                  onOpenServices: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnlineRateList(
                        repository: session.repository,
                        businessId: active.id,
                      ),
                    ),
                  ),
                  onOpenBilling: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkspaceScreen(
                        repository: session.repository,
                        business: active,
                      ),
                    ),
                  ),
                  onOpenOffline: widget.onOpenOffline,
                )
              else if (pendingBusinesses.length == 1)
                BusinessApproval(
                  business: pendingBusinesses.first,
                  repository: session.repository,
                  onRefresh: () {
                    unawaited(() async {
                      await session.reload();
                      if (mounted) {
                        setState(() {
                          _invite = null;
                          _team = null;
                        });
                      }
                    }());
                  },
                  onEdit: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessForm(
                          repository: session.repository,
                          business: pendingBusinesses.first,
                        ),
                      ),
                    );
                    if (saved == true) await session.reload();
                    if (mounted) setState(() {});
                  },
                )
              else if (pendingBusinesses.isNotEmpty) ...[
                const Text(
                  'Waiting for approval',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick a salon to check approval status.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                WorkspaceCards(
                  children: [
                    for (final business in pendingBusinesses)
                      WorkspaceCard(
                        title: business.name,
                        leading: BusinessPhoto(
                          repository: session.repository,
                          business: business,
                        ),
                        subtitle: 'Awaiting approval · ${business.city}',
                        icon: Icons.hourglass_top_rounded,
                        onTap: () => _openSalon(business),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else if (workspace.businesses.isNotEmpty) ...[
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
                        subtitle: '${business.city} · ${business.area}',
                        icon: Icons.storefront_outlined,
                        onTap: () => _openSalon(business),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (active != null && pendingBusinesses.isNotEmpty) ...[
                const Text(
                  'Pending approval',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                WorkspaceCards(
                  children: [
                    for (final business in pendingBusinesses)
                      WorkspaceCard(
                        title: business.name,
                        subtitle: 'Awaiting approval · tap for details',
                        icon: Icons.hourglass_top_rounded,
                        onTap: () => _openSalon(business),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              // No business yet, or several businesses → show start / join cards.
              if (!singleBusiness) ...[
                Text(
                  workspace.businesses.isEmpty ? 'Get started' : 'More',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                WorkspaceCards(
                  children: [
                    if (workspace.businesses.isEmpty)
                      WorkspaceCard(
                        title: 'Start a business',
                        subtitle: 'Set up your salon and manage your team.',
                        icon: Icons.storefront_outlined,
                        onTap: () => _startBusiness(context),
                      ),
                    WorkspaceCard(
                      title: 'Join a salon',
                      subtitle:
                          'Barbers: finish your profile, then join with a code or QR.',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSalonHome extends StatelessWidget {
  const _ActiveSalonHome({
    required this.business,
    required this.repository,
    required this.invite,
    required this.team,
    required this.inviteCode,
    required this.reviewing,
    required this.onRetryInvite,
    required this.onRetryTeam,
    required this.onReview,
    required this.onInviteByProfile,
    required this.onOpenStaff,
    required this.onEditBusiness,
    required this.onOpenServices,
    required this.onOpenBilling,
    required this.onOpenOffline,
  });

  final SalonBusiness business;
  final OnlineRepository repository;
  final Future<String>? invite;
  final Future<List<SalonStaff>>? team;
  final TextEditingController inviteCode;
  final String? reviewing;
  final VoidCallback onRetryInvite;
  final VoidCallback onRetryTeam;
  final Future<void> Function(SalonStaff employee, bool accept) onReview;
  final Future<void> Function() onInviteByProfile;
  final VoidCallback onOpenStaff;
  final Future<void> Function() onEditBusiness;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenBilling;
  final VoidCallback onOpenOffline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BusinessPhoto(repository: repository, business: business),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Approved · ${business.city}',
                    style: const TextStyle(color: AppColors.homeOlive),
                  ),
                  Text(
                    '${business.area} · ${business.phone}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Manage salon',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        WorkspaceCards(
          children: [
            WorkspaceCard(
              title: 'Employees & contracts',
              subtitle: 'Requests, invite by code, agreements.',
              leading: FutureBuilder<List<SalonStaff>>(
                future: team,
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
                      color: AppColors.homeInk,
                    ),
                  );
                },
              ),
              icon: Icons.people_outline,
              onTap: onOpenStaff,
            ),
            WorkspaceCard(
              title: 'Services & prices',
              subtitle: 'Rate list and service media.',
              icon: Icons.list_alt,
              onTap: onOpenServices,
            ),
            WorkspaceCard(
              title: 'Billing workspace',
              subtitle: 'Bills, customers, finance — online & offline.',
              icon: Icons.point_of_sale_outlined,
              onTap: onOpenBilling,
            ),
            WorkspaceCard(
              title: 'Offline business app',
              subtitle: 'Open the full local salon tools.',
              icon: Icons.phone_android_outlined,
              onTap: onOpenOffline,
            ),
            WorkspaceCard(
              title: 'Business details',
              subtitle: 'Update salon information.',
              icon: Icons.edit_outlined,
              onTap: () => onEditBusiness(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'New employee requests',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (team == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          RemoteContent<List<SalonStaff>>(
            future: team!,
            onRetry: onRetryTeam,
            builder: (staff) {
              final pending = staff
                  .where((e) => e.joinStatus == 'pending')
                  .toList();
              if (pending.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No pending join requests right now.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: [
                  for (final employee in pending.take(5))
                    Card(
                      elevation: 0,
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.homeBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Wants to join your salon',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ActionButton(
                                    label: 'Decline',
                                    icon: Icons.close,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.background,
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: reviewing == employee.id
                                        ? () async {}
                                        : () => onReview(employee, false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ActionButton(
                                    label: 'Accept',
                                    icon: Icons.check,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: reviewing == employee.id
                                        ? () async {}
                                        : () => onReview(employee, true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: onOpenStaff,
                    child: const Text('View all employees'),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 20),
        const Text(
          'Add employee by profile code',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'If a barber already has a profile code, invite them directly.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: inviteCode,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Employee profile code',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ActionButton(
          label: 'Add employee',
          icon: Icons.person_add_outlined,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onInviteByProfile,
        ),
        const SizedBox(height: 24),
        const Text(
          'Employee joining code & QR',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share this code or QR so staff can request to join after their profile.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (invite == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          RemoteContent(
            future: invite!,
            onRetry: onRetryInvite,
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
        const SizedBox(height: 20),
        PublicQr(
          destination: QrDestination('salon', business.id),
          label: 'Customer salon QR',
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class OwnerBusiness extends StatefulWidget {
  const OwnerBusiness({
    super.key,
    required this.repository,
    required this.businessId,
    this.managementOnly = false,
    this.onApproved,
  });
  final OnlineRepository repository;
  final String businessId;
  final bool managementOnly;
  final Future<void> Function()? onApproved;

  @override
  State<OwnerBusiness> createState() => _OwnerBusinessState();
}

class _OwnerBusinessState extends State<OwnerBusiness> {
  late Future<OnlineWorkspace> _workspace = widget.repository.loadWorkspace();
  Future<String>? _invite;
  Future<List<SalonStaff>>? _team;
  late final Timer _poll;
  bool _leavingForHome = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _team != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _team = widget.repository.team(widget.businessId);
        });
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

  Future<void> _goHomeAfterApproval() async {
    if (_leavingForHome) return;
    _leavingForHome = true;
    await widget.onApproved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OnlineWorkspace>(
    future: _workspace,
    builder: (context, snapshot) {
      final matches = snapshot.data?.businesses.where(
        (business) => business.id == widget.businessId,
      );
      if (!widget.managementOnly &&
          matches != null &&
          matches.isNotEmpty &&
          matches.first.isActive) {
        return WorkspaceScreen(
          repository: widget.repository,
          business: matches.first,
        );
      }
      return _management(context);
    },
  );

  Widget _management(BuildContext context) => OnlinePage(
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
              onRefresh: () {
                final next = widget.repository.loadWorkspace();
                setState(() {
                  _workspace = next;
                  _invite = null;
                  _team = null;
                });
                unawaited(() async {
                  final latest = await next;
                  final current = latest.businesses.where(
                    (item) => item.id == widget.businessId,
                  );
                  if (current.isNotEmpty && current.first.isActive && mounted) {
                    await _goHomeAfterApproval();
                  }
                }());
              },
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
              Text(
                business.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Approved. Manage this salon from Home for requests, joining code and billing.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ActionButton(
                label: 'Back to home',
                icon: Icons.home_outlined,
                onPressed: () async {
                  await widget.onApproved?.call();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
              WorkspaceCards(
                children: [
                  WorkspaceCard(
                    title: 'Employees & contracts',
                    subtitle: 'Join requests, employees and agreements.',
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
                    title: 'Services & prices',
                    subtitle: 'Manage your rate list and service photos.',
                    icon: Icons.list_alt,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OnlineRateList(
                          repository: widget.repository,
                          businessId: business.id,
                        ),
                      ),
                    ),
                  ),
                  WorkspaceCard(
                    title: 'Billing workspace',
                    subtitle: widget.managementOnly
                        ? 'Managers cannot open billing. Ask the owner if you need access.'
                        : 'Open your salon’s online and offline workspace.',
                    icon: Icons.sync,
                    enabled: !widget.managementOnly,
                    onTap: widget.managementOnly
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkspaceScreen(
                                repository: widget.repository,
                                business: business,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ActionButton(
                label: 'Show employee joining code',
                icon: Icons.group_add_outlined,
                onPressed: () async {
                  final future = widget.repository.businessInvite(business.id);
                  setState(() => _invite = future);
                  await future;
                },
              ),
              if (_invite != null)
                RemoteContent(
                  future: _invite!,
                  onRetry: () => setState(
                    () =>
                        _invite = widget.repository.businessInvite(business.id),
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
        setState(() {
          _joinRequests = widget.repository.joinRequests();
        });
      }
    });
  }

  Future<void> _request() async {
    if (_requesting || !_form.currentState!.validate()) return;
    setState(() => _requesting = true);
    try {
      await widget.repository.requestJoin(_code.text.trim());
      if (mounted) {
        showMessage(context, 'Join request sent. Waiting for owner approval.');
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Join a salon'),
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
                      color: AppColors.homeOlive,
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
                      'Check your request status below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
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
                        color: AppColors.homeInk,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter your salon’s code or scan its QR.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
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
                                style: TextStyle(color: AppColors.textSecondary),
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
                          fillColor: AppColors.homeCanvas,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
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
          onPressed: () => setState(() {
            _joinRequests = widget.repository.joinRequests();
          }),
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
