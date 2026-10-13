import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SettledSalariesScreen extends StatefulWidget {
  const SettledSalariesScreen({super.key});

  @override
  State<SettledSalariesScreen> createState() => _SettledSalariesScreenState();
}

class _SettledSalariesScreenState extends State<SettledSalariesScreen> {
  FinancePeriod? _period;
  DateTime? _anchor;
  String? _employeeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_period != null) return;
    final args = FinanceRouteArgs.of(context);
    _period = args.period;
    _anchor = args.anchor;
  }

  @override
  Widget build(BuildContext context) {
    final period = _period!;
    final anchor = _anchor!;
    final inPeriod = context
        .watch<PayoutsStore>()
        .payouts
        .where(
          (p) => FinanceCalculator.periodContains(p.workDate, anchor, period),
        )
        .toList(growable: false);

    final employees = <String, String>{
      for (final p in inPeriod) p.employeeId: p.employeeName,
    };
    final selectedId = employees.containsKey(_employeeId) ? _employeeId : null;
    final items = inPeriod
        .where((p) => selectedId == null || p.employeeId == selectedId)
        .toList(growable: false);
    final total = items.fold<double>(0, (s, p) => s + p.amount);

    final byDay = <DateTime, List<SalaryPayout>>{};
    for (final p in items) {
      byDay.putIfAbsent(p.workDate, () => <SalaryPayout>[]).add(p);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, 'Settled Salaries'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 720 : double.infinity),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              FinancePeriodBar(
                period: period,
                anchor: anchor,
                onPeriodChanged: (p) => setState(() => _period = p),
                onAnchorChanged: (d) => setState(() => _anchor = d),
              ),
              if (employees.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FinanceChip(
                        label: 'All',
                        selected: selectedId == null,
                        onTap: () => setState(() => _employeeId = null),
                      ),
                      for (final e in employees.entries) ...[
                        const SizedBox(width: 6),
                        FinanceChip(
                          label: e.value,
                          selected: selectedId == e.key,
                          onTap: () => setState(() => _employeeId = e.key),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FinanceCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Settled',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${items.length} payouts',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FinanceFormat.money(total),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FinanceEmpty(
                    message: 'No salaries settled in this period.',
                  ),
                )
              else
                for (final day in days) ...[
                  FinanceDayHeader(
                    date: day,
                    trailing: FinanceFormat.money(
                      byDay[day]!.fold<double>(0, (s, p) => s + p.amount),
                    ),
                  ),
                  ...byDay[day]!.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _PayoutCard(payout: p),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final SalaryPayout payout;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              CupertinoIcons.checkmark_seal,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payout.employeeName.isEmpty ? 'Employee' : payout.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Settled ${FinanceFormat.date(payout.settledAt)}, '
                  '${FinanceFormat.time(payout.settledAt)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (payout.note != null)
                  Text(
                    payout.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            FinanceFormat.money(payout.amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
