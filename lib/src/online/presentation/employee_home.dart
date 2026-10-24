import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import 'business_form.dart';
import 'business_home.dart' show JoinSalon;
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
    this.onSwitchWorkspace,
  });
  final OnlineSession session;
  final Future<void> Function() onSignOut;
  final VoidCallback? onSwitchWorkspace;

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  late Future<EmployeeDashboardData> _data = widget.session.repository
      .employeeDashboard();
  late Future<List<PendingEmployeeInvite>> _invites = widget.session.repository
      .pendingInvitesForMe();
  var _period = _WorkPeriod.daily;
  late DateTime _anchor = DateTime.now();

  void _refresh() => setState(() {
    _data = widget.session.repository.employeeDashboard();
    _invites = widget.session.repository.pendingInvitesForMe();
  });

  Future<void> _respondToInvite(
    PendingEmployeeInvite invite, {
    required bool accept,
  }) async {
    await widget.session.repository.respondToEmployeeInvite(invite.id, accept);
    if (!mounted) return;
    if (accept) {
      showMessage(context, 'Joined ${invite.businessName}');
      await widget.session.reload();
    } else {
      showMessage(context, 'Invite declined');
    }
    if (mounted) _refresh();
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
          if (widget.onSwitchWorkspace != null)
            IconButton(
              tooltip: 'Switch workspace',
              icon: const Icon(Icons.swap_horiz),
              onPressed: widget.onSwitchWorkspace,
            ),
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
      body: SafeArea(
        top: false,
        child: OnlineShell.centered(
          maxWidth: OnlineShell.pageMaxWidth,
          child: RemoteContent(
            future: _data,
            onRetry: _refresh,
            builder: (data) {
              final filtered = data.days
                  .where((d) => _inPeriod(d.date))
                  .toList();
              // If today is empty, still show the latest working day so staff
              // immediately see what they completed after a contract starts.
              final days = filtered.isNotEmpty
                  ? filtered
                  : (_period == _WorkPeriod.daily && data.days.isNotEmpty
                        ? <EmployeeDayWork>[data.days.first]
                        : filtered);
              final sales = days.fold<double>(0, (s, d) => s + d.sales);
              final jobs = days.fold<int>(0, (s, d) => s + d.jobCount);
              final acceptedMemberships = data.joinRequests
                  .where((r) => r.status == 'accepted')
                  .toList();
              final hasSalonWork =
                  acceptedMemberships.isNotEmpty ||
                  data.liveContracts.isNotEmpty ||
                  data.notifiedContracts.isNotEmpty;

              return FutureBuilder<List<PendingEmployeeInvite>>(
                future: _invites,
                builder: (context, inviteSnap) {
                  final invites =
                      inviteSnap.data ?? const <PendingEmployeeInvite>[];
                  final invitesLoading =
                      inviteSnap.connectionState == ConnectionState.waiting &&
                      !inviteSnap.hasData;

                  // Invited before signup: after profile, only Yes/No — no Get started.
                  if (!hasSalonWork && invitesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!hasSalonWork && invites.isNotEmpty) {
                    return _PendingInviteDecision(
                      invites: invites,
                      onAccept: (invite) =>
                          _respondToInvite(invite, accept: true),
                      onDecline: (invite) =>
                          _respondToInvite(invite, accept: false),
                    );
                  }

                  // Declined / no invite: Start a business or Join a salon.
                  if (!hasSalonWork) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                if (!mounted || saved != true) return;
                                showMessage(
                                  this.context,
                                  'Business saved. It opens after admin approval.',
                                );
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
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _ProfileHeader(
                        name: workspace.account.name,
                        phone: profile?.phone ?? '',
                        experience: profile?.experienceAt(DateTime.now()) ?? '',
                        photoFuture: widget.session.repository.profilePhoto(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (invites.isNotEmpty) ...[
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
                                    label: 'No',
                                    showIcon: false,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.background,
                                      foregroundColor: AppColors.textPrimary,
                                    ),
                                    onPressed: () =>
                                        _respondToInvite(invite, accept: false),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: ActionButton(
                                    label: 'Yes',
                                    showIcon: false,
                                    onPressed: () =>
                                        _respondToInvite(invite, accept: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (data.notifiedContracts.isNotEmpty) ...[
                        Text('Your contracts', style: text.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        for (final contract in data.notifiedContracts)
                          _ContractNotice(contract: contract),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (data.liveContracts.isEmpty &&
                          data.notifiedContracts.isEmpty) ...[
                        for (final membership in acceptedMemberships) ...[
                          _JoinedSalonCard(
                            businessName: membership.businessName,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const _BannerPanel(
                          title: 'Contract pending',
                          subtitle:
                              'Waiting for your contract to start. After it begins, every bill you complete shows here.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (data.liveContracts.isNotEmpty) ...[
                        for (final contract in data.liveContracts) ...[
                          _SalonSummaryCard(contract: contract),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Daily work',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
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
                              if (picked != null) {
                                setState(() => _anchor = picked);
                              }
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
                            child: _StatTile(label: 'Jobs', value: '$jobs'),
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
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              '${day.date.day}/${day.date.month}/${day.date.year}',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          for (final job in day.jobs)
                            _JobListTile(
                              job: job,
                              money: _money,
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _JobDetailPage(job: job),
                                ),
                              ),
                            ),
                        ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _WorkPeriod { daily, weekly, monthly }

/// Full-screen gate after profile: accept or decline a pre-registration invite.
class _PendingInviteDecision extends StatelessWidget {
  const _PendingInviteDecision({
    required this.invites,
    required this.onAccept,
    required this.onDecline,
  });

  final List<PendingEmployeeInvite> invites;
  final Future<void> Function(PendingEmployeeInvite invite) onAccept;
  final Future<void> Function(PendingEmployeeInvite invite) onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final invite = invites.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.homeBorder),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 26,
                      color: AppColors.homeInk,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  invite.businessName,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${invite.ownerName} added you to this salon.',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.homeOlive,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Do you want to be part of this team? Choose yes to open your employee profile for this salon, or no to continue on your own.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  label: 'Yes, join ${invite.businessName}',
                  showIcon: false,
                  onPressed: () => onAccept(invite),
                ),
                const SizedBox(height: 10),
                ActionButton(
                  label: 'No, not now',
                  showIcon: false,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: () => onDecline(invite),
                ),
                if (invites.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'You have ${invites.length - 1} more invite${invites.length == 2 ? '' : 's'} after this.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinedSalonCard extends StatelessWidget {
  const _JoinedSalonCard({required this.businessName});
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your salon',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              businessName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerPanel extends StatelessWidget {
  const _BannerPanel({required this.title, required this.subtitle, this.child});
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
          if (child != null) ...[const SizedBox(height: AppSpacing.sm), child!],
        ],
      ),
    );
  }
}

class _SalonSummaryCard extends StatelessWidget {
  const _SalonSummaryCard({required this.contract});
  final WorkContract contract;

  String get _kindLabel => switch (contract.kind) {
    'permanent' => 'Permanent',
    'daily' => 'Daily',
    'fixed' => 'Fixed term',
    _ => contract.kind,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your salon',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              contract.businessName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'Employment type',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              _kindLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'Commission',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              '${contract.commission.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
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
                    PkPhone.localNumber(phone),
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

class _JobListTile extends StatelessWidget {
  const _JobListTile({
    required this.job,
    required this.money,
    required this.onTap,
  });

  final EmployeeWorkJob job;
  final String Function(double) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.homeBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.customerName.trim().isEmpty
                              ? 'Customer'
                              : job.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total ${money(job.total)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.iconMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobDetailPage extends StatelessWidget {
  const _JobDetailPage({required this.job});

  final EmployeeWorkJob job;

  String _money(double value) => value.toStringAsFixed(0);

  String get _time =>
      '${job.createdAt.hour.toString().padLeft(2, '0')}:'
      '${job.createdAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(
          'Job detail',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _JobField(
                    label: 'Customer',
                    value: job.customerName.trim().isEmpty
                        ? '—'
                        : job.customerName,
                  ),
                  _JobField(label: 'Salon', value: job.businessName),
                  _JobField(
                    label: 'Services',
                    value: job.services.isEmpty ? '—' : job.services.join(', '),
                  ),
                  _JobField(label: 'Time', value: _time),
                  _JobField(label: 'Total to salon', value: _money(job.total)),
                  _JobField(
                    label: 'Your commission',
                    value:
                        '+${_money(job.earning)}'
                        ' (${job.commissionPercent.toStringAsFixed(0)}%)',
                    valueColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobField extends StatelessWidget {
  const _JobField({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractNotice extends StatelessWidget {
  const _ContractNotice({required this.contract});
  final WorkContract contract;

  String get _kindLabel => switch (contract.kind) {
    'permanent' => 'Permanent',
    'daily' => 'Daily',
    'fixed' => 'Fixed term',
    _ => contract.kind,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contract.businessName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _JobField(label: 'Employment type', value: _kindLabel),
            _JobField(label: 'Status', value: contract.displayStatus),
            _JobField(
              label: 'Salary',
              value: contract.salary.toStringAsFixed(0),
            ),
            _JobField(
              label: 'Commission',
              value: '${contract.commission.toStringAsFixed(0)}%',
            ),
            if (contract.terms.trim().isNotEmpty)
              _JobField(
                label: 'Agreement description',
                value: contract.terms.trim(),
              ),
          ],
        ),
      ),
    );
  }
}
