import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_payments_screen.dart';
import '../../core/widgets/app_confirm_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import 'business_form.dart';
import 'business_home.dart' show JoinSalon;
import 'online_session.dart';
import 'profile_form.dart';
import 'widgets/online_widgets.dart';
import 'widgets/workspace_card.dart';
import '../../features/finance/presentation/sales_screen.dart';
import '../../features/finance/presentation/finance_format.dart';
import '../../features/finance/presentation/widgets/finance_widgets.dart';
import '../../features/finance/domain/entities/finance_period.dart';
import '../../features/billing/domain/entities/bill.dart';
import '../../features/billing/presentation/widgets/pos_receipt_card.dart';

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

class _EmployeeHomeState extends State<EmployeeHome>
    with WidgetsBindingObserver {
  Timer? _poll;
  final Set<String> _seenNotices = {};
  String get _noticeKey =>
      'employee-notices-${widget.session.workspace?.account.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSeenNotices());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          ModalRoute.of(context)?.isCurrent == true) {
        _refresh();
      }
    });
  }

  Future<void> _loadSeenNotices() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final seen = preferences.getStringList(_noticeKey) ?? [];
      if (mounted) setState(() => _seenNotices.addAll(seen));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openPayments([List<EmployeeDayWork>? days]) async {
    late List<EmployeeDayWork> values;
    try {
      values = days ?? (await _data).days;
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not load payments. Please retry.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeePaymentsScreen(
          days: values,
          workDate: days?.length == 1 ? days!.single.date : null,
          onRefresh: widget.session.repository.employeeDashboard,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _openNotifications() async {
    late EmployeeDashboardData data;
    try {
      data = await _data;
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not load notifications. Please retry.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeNotificationsScreen(
          notices: data.notifications,
          onRefresh: widget.session.repository.employeeDashboard,
          seen: _seenNotices,
          onRead: (notice) async {
            _seenNotices.add(notice.id);
            try {
              final preferences = await SharedPreferences.getInstance();
              await preferences.setStringList(
                _noticeKey,
                _seenNotices.toList(),
              );
            } catch (_) {}
            if (!mounted) return;
            try {
              final latest = await widget.session.repository
                  .employeeDashboard();
              if (!mounted) return;
              if (notice.payment != null) {
                final date = notice.payment!.payout.workDate;
                await _openPayments(
                  latest.days
                      .where(
                        (day) =>
                            day.date.year == date.year &&
                            day.date.month == date.month &&
                            day.date.day == date.day,
                      )
                      .toList(),
                );
              } else {
                await _showContracts(latest);
              }
            } catch (_) {
              if (mounted) {
                showMessage(
                  context,
                  'Could not open this update. Please retry.',
                  error: true,
                );
              }
            }
          },
        ),
      ),
    );
    if (mounted) _refresh();
  }

  late Future<EmployeeDashboardData> _data = widget.session.repository
      .employeeDashboard();
  late Future<List<PendingEmployeeInvite>> _invites = widget.session.repository
      .pendingInvitesForMe();
  var _period = FinancePeriod.daily;
  late final _photo = widget.session.repository.profilePhoto();
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
    } else {
      showMessage(context, 'Invite declined');
    }
    await widget.session.reload();
    if (mounted) _refresh();
  }

  Future<void> _leave(SalonJoinRequest membership) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Leave this business?',
      message:
          'Leave ${membership.businessName}? Your employee and manager access will end. Your previous work records will stay saved.',
      confirmLabel: 'Leave business',
      isDestructive: true,
    );
    if (confirm != true || !mounted) return;
    await widget.session.repository.leaveBusiness(membership.businessId);
    await widget.session.reload();
    if (mounted) _refresh();
  }

  void _openJob(EmployeeWorkJob job) => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => _JobDetailPage(job: job)),
  );
  void _openSales(EmployeeDashboardData data) {
    final jobs = data.days.expand((day) => day.jobs).toList();
    final byId = {for (final job in jobs) job.id: job};
    final bills = jobs
        .map(
          (job) =>
              job.bill ??
              Bill(
                id: job.id,
                createdAt: job.createdAt,
                customerName: job.customerName,
                customerPhone: '',
                employeeName: widget.session.workspace!.account.name,
                paymentType: job.paymentType,
                lines: job.services
                    .map((name) => BillLine(serviceName: name, price: 0))
                    .toList(),
                subTotal: job.commissionBase,
                taxPercent: 0,
                taxAmount: 0,
                grandTotal: job.total,
              ),
        )
        .toList();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: FinanceRouteArgs(anchor: _anchor, period: _period),
        ),
        builder: (_) => SalesScreen(
          title: 'My sales',
          employeeView: true,
          suppliedBills: bills,
          commissionByBill: {for (final job in jobs) job.id: job.earning},
          onOpenBill: (bill) => _openJob(byId[bill.id]!),
        ),
      ),
    );
  }

  Future<void> _showContracts(EmployeeDashboardData data) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'My contracts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                if (data.liveContracts.isEmpty &&
                    data.notifiedContracts.isEmpty)
                  const Text('Your owner has not set a contract yet.'),
                for (final contract in data.liveContracts)
                  _SalonSummaryCard(contract: contract),
                for (final contract in data.notifiedContracts)
                  _ContractNotice(contract: contract),
              ],
            ),
          ),
        ),
      );

  bool _inPeriod(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case FinancePeriod.daily:
        return day == anchor;
      case FinancePeriod.weekly:
        final start = anchor.subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return !day.isBefore(start) && !day.isAfter(end);
      case FinancePeriod.monthly:
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'TrimMatrix',
          style: text.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          FutureBuilder<EmployeeDashboardData>(
            future: _data,
            builder: (context, snapshot) {
              final unread =
                  snapshot.data?.notifications
                      .where((n) => !_seenNotices.contains(n.id))
                      .length ??
                  0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: snapshot.hasData ? () => _openNotifications() : null,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(CupertinoIcons.bell),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Employee menu',
            icon: const Icon(CupertinoIcons.ellipsis_circle),
            onSelected: (value) async {
              if (value == 'refresh') _refresh();
              if (value == 'payments') await _openPayments();
              if (!context.mounted) return;
              if (value == 'switch') widget.onSwitchWorkspace?.call();
              if (value == 'profile') {
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
              }
              if (value == 'signout') await widget.onSignOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Personal profile'),
              ),
              if (widget.onSwitchWorkspace != null)
                const PopupMenuItem(
                  value: 'switch',
                  child: Text('Switch workspace'),
                ),
              const PopupMenuItem(
                value: 'payments',
                child: Text('Payments & settlement'),
              ),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
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
            keepDataWhileLoading: true,
            onRetry: _refresh,
            builder: (data) {
              final filtered = data.days
                  .where((d) => _inPeriod(d.date))
                  .toList();
              final days = filtered;
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1FBCF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EMPLOYEE ACCOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: AppColors.homeOlive,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                FutureBuilder<String?>(
                                  future: _photo,
                                  builder: (_, snapshot) => CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.white,
                                    foregroundImage: snapshot.data == null
                                        ? null
                                        : NetworkImage(snapshot.data!),
                                    onForegroundImageError:
                                        snapshot.data == null
                                        ? null
                                        : (_, stack) {},
                                    child: const Icon(
                                      CupertinoIcons.person_crop_circle,
                                      size: 31,
                                      color: AppColors.homeOlive,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workspace.account.name,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -.4,
                                          color: AppColors.homeInk,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        PkPhone.localNumber(profile?.phone),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.homeOlive,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              acceptedMemberships.firstOrNull?.businessName ??
                                  data
                                      .liveContracts
                                      .firstOrNull
                                      ?.businessName ??
                                  data
                                      .notifiedContracts
                                      .firstOrNull
                                      ?.businessName ??
                                  'Your salon',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.homeInk,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              acceptedMemberships.firstOrNull?.isActive == false
                                  ? 'Inactive employee'
                                  : 'Active employee',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.homeOlive,
                              ),
                            ),
                            if (acceptedMemberships.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ActionButton(
                                label: 'Leave business',
                                showIcon: false,
                                onPressed: () =>
                                    _leave(acceptedMemberships.first),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.homeOlive,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontSize: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Sales',
                              value: 'Rs ${_money(sales)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(
                              label: 'Your share',
                              value:
                                  'Rs ${_money(days.fold<double>(0, (sum, day) => sum + day.earning))}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(label: 'Jobs', value: '$jobs'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _EmployeeAction(
                              label: 'My sales',
                              subtitle: 'Bills & payment methods',
                              icon: CupertinoIcons.chart_bar,
                              onTap: () => _openSales(data),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EmployeeAction(
                              label: 'My contracts',
                              subtitle: 'Terms & commission',
                              icon: CupertinoIcons.doc_text,
                              onTap: () => _showContracts(data),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _openPayments(),
                        icon: const Icon(
                          CupertinoIcons.money_dollar_circle,
                          size: 19,
                        ),
                        label: const Text('Payments & settlement'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.homeOlive,
                          minimumSize: const Size(double.infinity, 46),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Daily work',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.homeInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FinancePeriodBar(
                        period: _period,
                        anchor: _anchor,
                        onPeriodChanged: (p) => setState(() => _period = p),
                        onAnchorChanged: (d) => setState(() => _anchor = d),
                      ),
                      const SizedBox(height: 16),
                      if (data.liveContracts.isEmpty &&
                          data.notifiedContracts.isEmpty)
                        const _BannerPanel(
                          title: 'Contract pending',
                          subtitle:
                              'Your owner will set your employment terms. Your recorded work stays saved.',
                        ),
                      if (days.isEmpty)
                        const FinanceEmpty(
                          message: 'No work recorded for this period yet.',
                        ),
                      for (final day in days) ...[
                        FinanceDayHeader(
                          date: day.date,
                          trailing: FinanceFormat.money(day.sales),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _openPayments([day]),
                            child: Text(
                              '${day.settlementStatus} · ${FinanceFormat.money(day.due)} pending',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.homeOlive,
                              ),
                            ),
                          ),
                        ),
                        for (final job in day.jobs)
                          _JobListTile(
                            job: job,
                            money: _money,
                            onTap: () => _openJob(job),
                          ),
                      ],
                      if (invites.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Salon invites'),
                        for (final invite in invites)
                          _BannerPanel(
                            title: 'Added by ${invite.ownerName}',
                            subtitle: 'Join ${invite.businessName}?',
                            child: ActionButton(
                              label: 'Yes, join ${invite.businessName}',
                              showIcon: false,
                              onPressed: () =>
                                  _respondToInvite(invite, accept: true),
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
                      CupertinoIcons.building_2_fill,
                      size: 26,
                      color: AppColors.homeInk,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  invite.businessName,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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

class _EmployeeAction extends StatelessWidget {
  const _EmployeeAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String label, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.homeOlive),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job.paymentType} · Rs ${money(job.total)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Sale details',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
          if (job.bill != null)
            PosReceiptCard(
              bill: job.bill!,
              businessName: job.businessName,
              currencyCode: 'PKR',
            ),
          const SizedBox(height: 14),
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
                  if (job.bill == null) ...[
                    _JobField(
                      label: 'Customer',
                      value: job.customerName.trim().isEmpty
                          ? '—'
                          : job.customerName,
                    ),
                    _JobField(label: 'Salon', value: job.businessName),
                    _JobField(
                      label: 'Services',
                      value: job.services.isEmpty
                          ? '—'
                          : job.services.join(', '),
                    ),
                    _JobField(label: 'Time', value: _time),
                    _JobField(
                      label: 'Total to salon',
                      value: _money(job.total),
                    ),
                  ],
                  _JobField(
                    label: 'Original service amount',
                    value: _money(job.commissionBase),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Shop discounts do not reduce your share. Tax is separate.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
