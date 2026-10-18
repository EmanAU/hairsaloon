import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import 'business_home.dart';
import 'staff_screen.dart';
import 'rate_list_screen.dart';
import 'qr_screen.dart';
import '../domain/qr_destination.dart';
import 'widgets/online_widgets.dart';

class OnlineDashboardTools extends StatefulWidget {
  const OnlineDashboardTools({
    super.key,
    required this.workspace,
    required this.onSync,
    required this.onClose,
    required this.onBusinessChanged,
  });
  final BusinessWorkspace workspace;
  final VoidCallback onSync, onClose;
  final Future<void> Function() onBusinessChanged;
  @override
  State<OnlineDashboardTools> createState() => _OnlineDashboardToolsState();
}

class _OnlineDashboardToolsState extends State<OnlineDashboardTools> {
  late Future<List<SalonStaff>> _team = _load();
  late final Timer _poll;
  final _inviteCode = TextEditingController();
  Future<String>? _invite;
  bool _reviewing = false;
  Future<List<SalonStaff>> _load() =>
      widget.workspace.repository.team(widget.workspace.business.id);
  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _team = _load();
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

  Future<void> _review(SalonStaff employee, bool accept) async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    try {
      await widget.workspace.repository.reviewJoin(employee.id, accept);
      if (mounted) {
        setState(() {
          _team = _load();
        });
      }
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      setState(() {
        _team = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final business = workspace.business;
    final repository = workspace.repository;
    return Column(
      children: [
        GridView(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: MediaQuery.sizeOf(context).shortestSide >= 600
                ? 144
                : 118,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FutureBuilder<List<SalonStaff>>(
              future: _team,
              builder: (context, snapshot) {
                final count = snapshot.data
                    ?.where((e) => e.joinStatus == 'pending')
                    .length;
                return DashboardShortcut(
                  title: 'Join requests',
                  badge: count ?? 0,
                  detail: snapshot.hasError
                      ? 'Check requests\nfrom your team.'
                      : count == null
                      ? 'Loading requests…'
                      : '$count pending\njoin requests.',
                  asset: 'employees',
                  tint: const Color(0xFFF0FBDD),
                  onTap: () => _open(
                    StaffScreen(
                      repository: repository,
                      businessId: business.id,
                      showRequests: true,
                      workspace: workspace,
                    ),
                  ),
                );
              },
            ),
            DashboardShortcut(
              title: 'Contracts',
              detail: 'Manage employee\nagreements.',
              asset: 'employees',
              tint: const Color(0xFFE1FBEC),
              onTap: () => _open(
                StaffScreen(
                  repository: repository,
                  businessId: business.id,
                  showRequests: false,
                  workspace: workspace,
                ),
              ),
            ),
            DashboardShortcut(
              title: 'Online services',
              detail: 'Photos, videos\nand service prices.',
              asset: 'rates',
              tint: const Color(0xFFFFF4DB),
              onTap: () => _open(
                OnlineRateList(repository: repository, businessId: business.id),
              ),
            ),
            DashboardShortcut(
              title: 'Business details',
              detail: 'Business profile,\njoining code and QR.',
              asset: 'shop',
              tint: const Color(0xFFEAF0FF),
              onTap: () async {
                await _open(
                  OwnerBusiness(
                    repository: repository,
                    businessId: business.id,
                    managementOnly: true,
                  ),
                );
                if (mounted) await widget.onBusinessChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<SalonStaff>>(
          future: _team,
          builder: (context, snapshot) {
            final pending =
                snapshot.data
                    ?.where((e) => e.joinStatus == 'pending')
                    .take(3)
                    .toList() ??
                [];
            if (pending.isEmpty) return const SizedBox.shrink();
            return AbsorbPointer(
              absorbing: _reviewing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'New employee requests',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  for (final employee in pending)
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Wants to join your salon'),
                            Row(
                              children: [
                                Expanded(
                                  child: ActionButton(
                                    label: 'Decline',
                                    icon: Icons.close,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFF3F5F7),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _review(employee, false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ActionButton(
                                    label: 'Accept',
                                    icon: Icons.check,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _review(employee, true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inviteCode,
          decoration: InputDecoration(
            labelText: 'Employee profile code',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ActionButton(
            label: 'Add employee',
            icon: Icons.person_add_outlined,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (!RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              ).hasMatch(_inviteCode.text.trim())) {
                throw const OnlineFailure('Paste a valid profile code');
              }
              await repository.inviteEmployee(
                business.id,
                _inviteCode.text.trim(),
              );
              if (mounted) {
                setState(() {
                  _inviteCode.clear();
                  _team = _load();
                });
              }
            },
          ),
        ),
        ExpansionTile(
          title: const Text(
            'Employee joining code & QR',
            style: TextStyle(fontSize: 14),
          ),
          tilePadding: EdgeInsets.zero,
          onExpansionChanged: (open) {
            if (open && _invite == null) {
              setState(() {
                _invite = repository.businessInvite(business.id);
              });
            }
          },
          children: [
            if (_invite != null)
              RemoteContent(
                future: _invite!,
                onRetry: () => setState(() {
                  _invite = repository.businessInvite(business.id);
                }),
                builder: (code) => Column(
                  children: [
                    ListTile(
                      title: const Text('Salon joining code'),
                      subtitle: SelectableText(code),
                      trailing: IconButton(
                        tooltip: 'Copy joining code',
                        icon: const Icon(Icons.copy),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: code)),
                      ),
                    ),
                    PublicQr(
                      destination: QrDestination('join', code),
                      label: 'Employee invitation QR',
                    ),
                    PublicQr(
                      destination: QrDestination('salon', business.id),
                      label: 'Customer salon QR',
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: widget.onSync,
                icon: const Icon(Icons.sync, size: 18),
                label: ListenableBuilder(
                  listenable: workspace,
                  builder: (context, _) =>
                      Text(workspace.conflict ? 'Resolve sync' : 'Sync status'),
                ),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Switch business'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
