import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/online_models.dart';
import 'contracts_screen.dart';
import 'business_form.dart';
import 'business_home.dart';
import 'online_session.dart';
import 'profile_form.dart';
import 'widgets/online_widgets.dart';

/// Home for staff who joined a salon (not business owners).
class EmployeeHome extends StatefulWidget {
  const EmployeeHome({
    super.key,
    required this.session,
    required this.onSignOut,
  });
  final OnlineSession session;
  final Future<void> Function() onSignOut;

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  late Future<EmployeeDashboardData> _data = widget.session.repository
      .employeeDashboard();
  late Future<List<PendingEmployeeInvite>> _invites = widget.session.repository
      .pendingInvitesForMe();
  late Future<List<ManagerBusiness>> _managerSalons = widget
      .session
      .repository
      .myManagerBusinesses();
  late final Timer _poll;
  var _period = _WorkPeriod.daily;
  late DateTime _anchor = DateTime.now();

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  void _refresh() => setState(() {
    _data = widget.session.repository.employeeDashboard();
    _invites = widget.session.repository.pendingInvitesForMe();
    _managerSalons = widget.session.repository.myManagerBusinesses();
  });

  Future<void> _openManagerDashboard(ManagerBusiness salon) async {
    final pin = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manager PIN · ${salon.businessName}'),
        content: TextField(
          controller: pin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '4-digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      pin.dispose();
      return;
    }
    try {
      final ok = await widget.session.repository.verifyManagerPin(
        salon.businessId,
        pin.text.trim(),
      );
      if (!ok) {
        showMessage(context, 'Incorrect manager PIN', error: true);
        return;
      }
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerBusiness(
            repository: widget.session.repository,
            businessId: salon.businessId,
            managementOnly: true,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is OnlineFailure
              ? error.message
              : 'Could not open manager dashboard.',
          error: true,
        );
      }
    } finally {
      pin.dispose();
    }
  }

  bool _inPeriod(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _WorkPeriod.daily:
        return day == anchor;
      case _WorkPeriod.weekly:
        final start = anchor.subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return !day.isBefore(start) && !day.isAfter(end);
      case _WorkPeriod.monthly:
        return day.year == anchor.year && day.month == anchor.month;
    }
  }

  String _money(double value) => value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final workspace = widget.session.workspace!;
    final profile = workspace.profile;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        title: const Text(
          'My work',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileForm(
                    repository: widget.session.repository,
                    profile: profile,
                    name: workspace.account.name,
                  ),
                ),
              );
              if (saved == true) {
                await widget.session.reload();
                if (mounted) _refresh();
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'join') {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        JoinSalon(repository: widget.session.repository),
                  ),
                );
                if (mounted) _refresh();
              } else if (value == 'contracts') {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ContractsScreen(repository: widget.session.repository),
                  ),
                );
                if (mounted) _refresh();
              } else {
                await widget.onSignOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'contracts', child: Text('My contracts')),
              PopupMenuItem(value: 'join', child: Text('Join another salon')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RemoteContent(
            future: _data,
            onRetry: _refresh,
            builder: (data) {
              final filtered =
                  data.days.where((d) => _inPeriod(d.date)).toList();
              // If today is empty, still show the latest working day so staff
              // immediately see what they completed after a contract starts.
              final days = filtered.isNotEmpty
                  ? filtered
                  : (_period == _WorkPeriod.daily && data.days.isNotEmpty
                        ? <EmployeeDayWork>[data.days.first]
                        : filtered);
              final sales = days.fold<double>(0, (s, d) => s + d.sales);
              final earning = days.fold<double>(0, (s, d) => s + d.earning);
              final jobs = days.fold<int>(0, (s, d) => s + d.jobCount);
              final hasSalonWork =
                  data.liveContracts.isNotEmpty ||
                  data.notifiedContracts.isNotEmpty ||
                  data.joinRequests.isNotEmpty;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _ProfileHeader(
                    name: workspace.account.name,
                    phone: profile?.phone ?? '',
                    experience: profile?.experienceAt(DateTime.now()) ?? '',
                    photoFuture: widget.session.repository.profilePhoto(),
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<PendingEmployeeInvite>>(
                    future: _invites,
                    builder: (context, snapshot) {
                      final invites = snapshot.data ?? const [];
                      if (invites.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Salon invites',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final invite in invites)
                            Card(
                              elevation: 0,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFE3E7EC),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Added by ${invite.ownerName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Join ${invite.businessName}?',
                                      style: const TextStyle(
                                        color: Color(0xFF718094),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ActionButton(
                                            label: 'Not now',
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFF3F5F7,
                                              ),
                                              foregroundColor: Colors.black,
                                            ),
                                            onPressed: () async {
                                              await widget.session.repository
                                                  .respondToEmployeeInvite(
                                                    invite.id,
                                                    false,
                                                  );
                                              if (mounted) {
                                                showMessage(
                                                  context,
                                                  'Invite declined',
                                                );
                                                _refresh();
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ActionButton(
                                            label: 'Join salon',
                                            onPressed: () async {
                                              await widget.session.repository
                                                  .respondToEmployeeInvite(
                                                    invite.id,
                                                    true,
                                                  );
                                              if (mounted) {
                                                showMessage(
                                                  context,
                                                  'Joined ${invite.businessName}',
                                                );
                                                _refresh();
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<List<ManagerBusiness>>(
                    future: _managerSalons,
                    builder: (context, snapshot) {
                      final salons = snapshot.data ?? const [];
                      if (salons.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Manager access',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final salon in salons)
                            ActionButton(
                              label: 'Open ${salon.businessName}',
                              icon: Icons.admin_panel_settings_outlined,
                              onPressed: () => _openManagerDashboard(salon),
                            ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  if (!hasSalonWork) ...[
                    const Text(
                      'Get started',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      label: 'Start a business',
                      icon: Icons.storefront_outlined,
                      onPressed: () async {
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusinessForm(
                              repository: widget.session.repository,
                              onRegistered:
                                  widget.session.rememberRegisteredBusiness,
                            ),
                          ),
                        );
                        await widget.session.reload();
                        if (saved == true && mounted) {
                          showMessage(
                            context,
                            'Business saved. It opens after admin approval.',
                          );
                        }
                      },
                    ),
                    ActionButton(
                      label: 'Join a salon',
                      icon: Icons.group_add_outlined,
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinSalon(
                              repository: widget.session.repository,
                            ),
                          ),
                        );
                        if (mounted) _refresh();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (data.notifiedContracts.isNotEmpty) ...[
                    const Text(
                      'Your contracts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final contract in data.notifiedContracts)
                      _ContractNotice(contract: contract),
                    const SizedBox(height: 16),
                  ],
                  if (hasSalonWork &&
                      data.liveContracts.isEmpty &&
                      data.notifiedContracts.isEmpty) ...[
                    const Card(
                      elevation: 0,
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Waiting for your contract to start. After it begins, every bill you complete shows here day by day.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF718094)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (data.liveContracts.isNotEmpty) ...[
                    Text(
                      data.liveContracts.length == 1
                          ? data.liveContracts.first.businessName
                          : 'Working at ${data.liveContracts.length} salons',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.liveContracts
                          .map(
                            (c) =>
                                '${c.kind} · ${c.commission.toStringAsFixed(0)}% commission',
                          )
                          .join(' · '),
                      style: const TextStyle(color: Color(0xFF718094)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (data.joinRequests.isNotEmpty) ...[
                    const Text(
                      'Join requests',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final request in data.joinRequests)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(request.businessName),
                        subtitle: Text(switch (request.status) {
                          'accepted' => 'Joined',
                          'declined' => 'Declined',
                          _ => 'Waiting for owner approval',
                        }),
                      ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daily work',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _anchor,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          );
                          if (picked != null) setState(() => _anchor = picked);
                        },
                        child: Text(
                          '${_anchor.day}/${_anchor.month}/${_anchor.year}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<_WorkPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: _WorkPeriod.daily,
                        label: Text('Daily'),
                      ),
                      ButtonSegment(
                        value: _WorkPeriod.weekly,
                        label: Text('Weekly'),
                      ),
                      ButtonSegment(
                        value: _WorkPeriod.monthly,
                        label: Text('Monthly'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (value) =>
                        setState(() => _period = value.first),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Sales',
                          value: _money(sales),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Your earning',
                          value: _money(earning),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Jobs',
                          value: '$jobs',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No work recorded for this period yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF718094)),
                      ),
                    )
                  else
                    for (final day in days) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          '${day.date.day}/${day.date.month}/${day.date.year}'
                          ' · ${_money(day.sales)} sales · ${_money(day.earning)} earning',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (final job in day.jobs)
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE3E7EC)),
                          ),
                          child: ListTile(
                            title: Text(job.customerName),
                            subtitle: Text(
                              [
                                job.businessName,
                                if (job.services.isNotEmpty)
                                  job.services.join(', '),
                                '${job.createdAt.hour.toString().padLeft(2, '0')}:'
                                    '${job.createdAt.minute.toString().padLeft(2, '0')}',
                              ].join(' · '),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _money(job.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '+${_money(job.earning)}',
                                  style: const TextStyle(
                                    color: Color(0xFF668400),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _WorkPeriod { daily, weekly, monthly }

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.experience,
    required this.photoFuture,
  });
  final String name;
  final String phone;
  final String experience;
  final Future<String?> photoFuture;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFE3E7EC)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          FutureBuilder<String?>(
            future: photoFuture,
            builder: (context, snapshot) {
              final url = snapshot.data;
              return CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF0F5DE),
                backgroundImage: url == null ? null : NetworkImage(url),
                child: url == null
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      )
                    : null,
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(phone, style: const TextStyle(color: Color(0xFF718094))),
                if (experience.isNotEmpty)
                  Text(
                    'Experience · $experience',
                    style: const TextStyle(color: Color(0xFF718094)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE3E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF718094), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ContractNotice extends StatelessWidget {
  const _ContractNotice({required this.contract});
  final WorkContract contract;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE3E7EC)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            contract.businessName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${contract.kind.toUpperCase()} · ${contract.displayStatus} · '
            'salary ${contract.salary.toStringAsFixed(0)} · '
            '${contract.commission.toStringAsFixed(0)}% commission',
            style: const TextStyle(color: Color(0xFF718094)),
          ),
          if (contract.terms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(contract.terms),
          ],
          const SizedBox(height: 8),
          const Text(
            'Your salon owner set these terms. No action is required from you.',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
