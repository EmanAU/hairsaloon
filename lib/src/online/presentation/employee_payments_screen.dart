import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../features/finance/presentation/finance_format.dart';
import '../../theme/app_colors.dart';
import '../domain/online_models.dart';

class EmployeePaymentsScreen extends StatefulWidget {
  const EmployeePaymentsScreen({
    super.key,
    required this.days,
    this.onRefresh,
    this.workDate,
  });
  final List<EmployeeDayWork> days;
  final DateTime? workDate;
  final Future<EmployeeDashboardData> Function()? onRefresh;
  @override
  State<EmployeePaymentsScreen> createState() => _EmployeePaymentsScreenState();
}

class _EmployeePaymentsScreenState extends State<EmployeePaymentsScreen> {
  late List<EmployeeDayWork> days = widget.days;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reload());
  }

  Future<void> _reload() async {
    if (_busy ||
        widget.onRefresh == null ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _busy = true;
    try {
      final fresh = await widget.onRefresh!();
      if (mounted) {
        setState(() {
          final date = widget.workDate;
          days = date == null
              ? fresh.days
              : fresh.days
                    .where(
                      (day) =>
                          day.date.year == date.year &&
                          day.date.month == date.month &&
                          day.date.day == date.day,
                    )
                    .toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not update payments. Pull down to retry.',
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EmployeePage(
    title: 'Payments & settlement',
    onRefresh: _reload,
    children: [
      Text(
        'Your earnings and payments',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Payments recorded by your salon appear here after syncing.',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 24),
      if (_error != null)
        Text(
          _error!,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      if (days.isEmpty) const Text('No earnings or payments yet.'),
      for (final day in days) ...[
        EmployeeSettlementTile(day: day),
        const SizedBox(height: 14),
      ],
    ],
  );
}

class EmployeeSettlementTile extends StatelessWidget {
  const EmployeeSettlementTile({super.key, required this.day});
  final EmployeeDayWork day;
  @override
  Widget build(BuildContext context) {
    final paid = day.settlementStatus == 'Paid';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${day.date.day}/${day.date.month}/${day.date.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFEDF6DD)
                      : const Color(0xFFFFF5DE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day.settlementStatus,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _amount('Earned', day.earning),
              _amount('Paid', day.paid),
              _amount('Pending', day.due),
              if (day.bonus > 0) _amount('Bonus included', day.bonus),
            ],
          ),
          if (day.payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            for (final payment in day.payments)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${payment.businessName} · ${FinanceFormat.money(payment.payout.amount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid on ${payment.payout.settledAt.toLocal().day}/${payment.payout.settledAt.toLocal().month}/${payment.payout.settledAt.toLocal().year}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (payment.payout.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        payment.payout.note!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _amount(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 5),
      Text(
        FinanceFormat.money(value),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({
    super.key,
    required this.notices,
    required this.seen,
    required this.onRead,
    this.onRefresh,
  });
  final List<EmployeeNotice> notices;
  final Set<String> seen;
  final Future<void> Function(EmployeeNotice notice) onRead;
  final Future<EmployeeDashboardData> Function()? onRefresh;
  @override
  State<EmployeeNotificationsScreen> createState() =>
      _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState
    extends State<EmployeeNotificationsScreen> {
  late List<EmployeeNotice> notices = widget.notices;
  Set<String> get seen => widget.seen;
  Timer? _timer;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reload());
  }

  Future<void> _reload() async {
    if (_busy ||
        widget.onRefresh == null ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _busy = true;
    try {
      final fresh = await widget.onRefresh!();
      if (mounted) setState(() => notices = fresh.notifications);
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EmployeePage(
    title: 'Notifications',
    onRefresh: _reload,
    children: [
      const Text(
        'Updates from your salon',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Contract and payment updates, all in one place.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 24),
      if (notices.isEmpty) const Text('No updates yet.'),
      for (final notice in notices)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StatefulBuilder(
            builder: (context, update) => Material(
              color: seen.contains(notice.id)
                  ? Colors.white
                  : const Color(0xFFF5F9E7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await widget.onRead(notice);
                  if (context.mounted) update(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        notice.payment == null
                            ? CupertinoIcons.doc_text
                            : CupertinoIcons.money_dollar_circle,
                        size: 22,
                        color: AppColors.homeOlive,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notice.message,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${notice.date.toLocal().day}/${notice.date.toLocal().month}/${notice.date.toLocal().year}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!seen.contains(notice.id))
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 4),
                          child: Icon(
                            CupertinoIcons.circle_fill,
                            size: 7,
                            color: AppColors.homeOlive,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _EmployeePage extends StatelessWidget {
  const _EmployeePage({
    required this.title,
    required this.children,
    this.onRefresh,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(CupertinoIcons.back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: onRefresh ?? () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
