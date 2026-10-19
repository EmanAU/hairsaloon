import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import 'invite_qr_screen.dart';
import 'join_requests_screen.dart';
import 'team_contracts_screen.dart';
import 'widgets/online_widgets.dart';

class OnlineDashboardTools extends StatefulWidget {
  const OnlineDashboardTools({
    super.key,
    required this.workspace,
    required this.onSync,
    required this.onClose,
  });
  final BusinessWorkspace workspace;
  final VoidCallback onSync, onClose;
  @override
  State<OnlineDashboardTools> createState() => _OnlineDashboardToolsState();
}

class _OnlineDashboardToolsState extends State<OnlineDashboardTools> {
  late Future<List<SalonStaff>> _team = _load();
  late final Timer _poll;
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
                  tint: AppColors.homeSage,
                  onTap: () => _open(
                    JoinRequestsScreen(
                      repository: repository,
                      businessId: business.id,
                      workspace: workspace,
                    ),
                  ),
                );
              },
            ),
            FutureBuilder<List<SalonStaff>>(
              future: _team,
              builder: (context, snapshot) {
                final needsContract = snapshot.data
                        ?.where(
                          (e) =>
                              e.joinStatus == 'accepted' && !e.isWorking,
                        )
                        .length ??
                    0;
                return DashboardShortcut(
                  title: 'Contracts',
                  badge: needsContract,
                  detail: snapshot.hasError
                      ? 'Employee list and\nagreements.'
                      : needsContract == 0
                      ? 'Employee list and\nagreements.'
                      : '$needsContract without\nactive contract.',
                  asset: 'employees',
                  tint: AppColors.homeSage,
                  onTap: () => _open(
                    TeamContractsScreen(
                      repository: repository,
                      businessId: business.id,
                    ),
                  ),
                );
              },
            ),
            DashboardShortcut(
              title: 'QR codes',
              detail: 'Joining code and\ninvite QR codes.',
              asset: 'rates',
              tint: AppColors.homeSand,
              onTap: () => _open(
                InviteQrScreen(
                  repository: repository,
                  businessId: business.id,
                ),
              ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: AppColors.homeBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
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
                                        backgroundColor: AppColors.background,
                                        foregroundColor: AppColors.textPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _review(employee, false),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ActionButton(
                                      label: 'Accept',
                                      icon: Icons.check,
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _review(employee, true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
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
