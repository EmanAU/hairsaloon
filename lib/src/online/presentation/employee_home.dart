import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import 'business_form.dart';
import 'business_home.dart';
import 'online_session.dart';
import 'profile_form.dart';
import 'widgets/online_widgets.dart';
import 'widgets/workspace_card.dart';

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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        title: Text('Your workspace', style: text.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(CupertinoIcons.person),
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
            icon: const Icon(CupertinoIcons.refresh),
          ),
          PopupMenuButton<String>(
            icon: const Icon(CupertinoIcons.ellipsis),
            onSelected: (value) async {
              if (value == 'signout') await widget.onSignOut();
            },
            itemBuilder: (_) => const [
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

              final invitesSection = _AsyncSection<List<PendingEmployeeInvite>>(
                future: _invites,
                onRetry: _refresh,
                errorLabel: 'Could not load salon invites.',
                builder: (invites) {
                  if (invites.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Salon invites', style: text.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      for (final invite in invites)
                        _BannerPanel(
                          title: 'Added by ${invite.ownerName}',
                          subtitle: 'Join ${invite.businessName}?',
                          child: Row(
                            children: [
                              Expanded(
                                child: ActionButton(
                                  label: 'Not now',
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.background,
                                    foregroundColor: AppColors.textPrimary,
                                  ),
                                  onPressed: () async {
                                    await widget.session.repository
                                        .respondToEmployeeInvite(
                                          invite.id,
                                          false,
                                        );
                                    if (mounted) {
                                      showMessage(context, 'Invite declined');
                                      _refresh();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
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
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
              );

              final managerSection = _AsyncSection<List<ManagerBusiness>>(
                future: _managerSalons,
                onRetry: _refresh,
                errorLabel: 'Could not load manager access.',
                builder: (salons) {
                  if (salons.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Manager access', style: text.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      for (final salon in salons)
                        ActionButton(
                          label: 'Open ${salon.businessName}',
                          icon: Icons.admin_panel_settings_outlined,
                          onPressed: () => _openManagerDashboard(salon),
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
              );

              // After personal profile: big Start / Join cards (same as before).
              if (!hasSalonWork) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      'Get started',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Choose how you want to use TrimMatrix.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    WorkspaceCards(
                      children: [
                        WorkspaceCard(
                          title: 'Start a business',
                          subtitle:
                              'Set up your salon and manage your team.',
                          icon: Icons.storefront_outlined,
                          onTap: () async {
                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BusinessForm(
                                  repository: widget.session.repository,
                                  onRegistered: widget
                                      .session
                                      .rememberRegisteredBusiness,
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
                        WorkspaceCard(
                          title: 'Join a salon',
                          subtitle:
                              'Finish with a code or QR from your salon owner.',
                          icon: Icons.group_add_outlined,
                          onTap: () async {
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
                      ],
                    ),
                    // Only when an employer invited this user (no error banners).
                    FutureBuilder<List<PendingEmployeeInvite>>(
                      future: _invites,
                      builder: (context, snapshot) {
                        final invites = snapshot.data;
                        if (invites == null || invites.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Salon invites',
                                style: text.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final invite in invites)
                                _BannerPanel(
                                  title: 'Added by ${invite.ownerName}',
                                  subtitle: 'Join ${invite.businessName}?',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ActionButton(
                                          label: 'Not now',
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.background,
                                            foregroundColor:
                                                AppColors.textPrimary,
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
                                      const SizedBox(width: AppSpacing.sm),
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
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _ProfileHeader(
                    name: workspace.account.name,
                    phone: profile?.phone ?? '',
                    experience: profile?.experienceAt(DateTime.now()) ?? '',
                    photoFuture: widget.session.repository.profilePhoto(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  invitesSection,
                  managerSection,
                  if (data.notifiedContracts.isNotEmpty) ...[
                    Text('Your contracts', style: text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    for (final contract in data.notifiedContracts)
                      _ContractNotice(contract: contract),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (hasSalonWork &&
                      data.liveContracts.isEmpty &&
                      data.notifiedContracts.isEmpty) ...[
                    _BannerPanel(
                      title: 'Contract pending',
                      subtitle:
                          'Waiting for your contract to start. After it begins, every bill you complete shows here.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (data.liveContracts.isNotEmpty) ...[
                    Text(
                      data.liveContracts.length == 1
                          ? data.liveContracts.first.businessName
                          : 'Working at ${data.liveContracts.length} salons',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      data.liveContracts
                          .map(
                            (c) =>
                                '${c.kind} · ${c.commission.toStringAsFixed(0)}% commission',
                          )
                          .join(' · '),
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (data.joinRequests.isNotEmpty) ...[
                    Text('Join requests', style: text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text('Daily work', style: text.titleMedium),
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
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Sales',
                          value: _money(sales),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Your earning',
                          value: _money(earning),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Jobs',
                          value: '$jobs',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (days.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        'No work recorded for this period yet.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final day in days) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xs,
                        ),
                        child: Text(
                          '${day.date.day}/${day.date.month}/${day.date.year}'
                          ' · ${_money(day.sales)} sales · ${_money(day.earning)} earning',
                          style: text.titleSmall,
                        ),
                      ),
                      for (final job in day.jobs)
                        _JobRow(
                          customerName: job.customerName,
                          detail: [
                            job.businessName,
                            if (job.services.isNotEmpty)
                              job.services.join(', '),
                            '${job.createdAt.hour.toString().padLeft(2, '0')}:'
                                '${job.createdAt.minute.toString().padLeft(2, '0')}',
                          ].join(' · '),
                          total: _money(job.total),
                          earning: '+${_money(job.earning)}',
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

class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.future,
    required this.onRetry,
    required this.errorLabel,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback onRetry;
  final String errorLabel;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: LinearProgressIndicator(minHeight: 2),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _BannerPanel(
          title: 'Something went wrong',
          subtitle: errorLabel,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}

class _BannerPanel extends StatelessWidget {
  const _BannerPanel({
    required this.title,
    required this.subtitle,
    this.child,
  });
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.homeSage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (child != null) ...[
            const SizedBox(height: AppSpacing.sm),
            child!,
          ],
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Row(
        children: [
          FutureBuilder<String?>(
            future: photoFuture,
            builder: (context, snapshot) {
              final url = snapshot.data;
              return CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.homeSage,
                backgroundImage: url == null ? null : NetworkImage(url),
                child: url == null
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: text.titleLarge,
                      )
                    : null,
              );
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleMedium),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (experience.isNotEmpty)
                  Text(
                    'Experience · $experience',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: text.titleLarge),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.customerName,
    required this.detail,
    required this.total,
    required this.earning,
  });
  final String customerName;
  final String detail;
  final String total;
  final String earning;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total, style: text.titleSmall),
              Text(
                earning,
                style: text.labelMedium?.copyWith(color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContractNotice extends StatelessWidget {
  const _ContractNotice({required this.contract});
  final WorkContract contract;

  @override
  Widget build(BuildContext context) => _BannerPanel(
    title: contract.businessName,
    subtitle:
        '${contract.kind.toUpperCase()} · ${contract.displayStatus} · '
        'salary ${contract.salary.toStringAsFixed(0)} · '
        '${contract.commission.toStringAsFixed(0)}% commission'
        '${contract.terms.isNotEmpty ? '\n${contract.terms}' : ''}\n'
        'Your salon owner set these terms. No action is required from you.',
  );
}
