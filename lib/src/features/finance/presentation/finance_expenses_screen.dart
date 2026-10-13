import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_details_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class FinanceExpensesScreen extends StatefulWidget {
  const FinanceExpensesScreen({super.key});

  @override
  State<FinanceExpensesScreen> createState() => _FinanceExpensesScreenState();
}

class _FinanceExpensesScreenState extends State<FinanceExpensesScreen> {
  FinancePeriod? _period;
  DateTime? _anchor;
  String _status = 'All';

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
    final items = context
        .watch<ExpensesStore>()
        .items
        .where((e) => FinanceCalculator.periodContains(e.date, anchor, period))
        .where(
          (e) =>
              _status == 'All' ||
              (_status == 'Paid' ? e.isPaid : e.isUnpaid),
        )
        .toList(growable: false);

    final total = items.fold<double>(0, (s, e) => s + e.amount);
    final byCategory = <String, double>{};
    final byDay = <DateTime, List<ExpenseItem>>{};
    for (final e in items) {
      final type = (e.expenseType?.trim().isNotEmpty ?? false)
          ? e.expenseType!.trim()
          : 'Other';
      byCategory.update(type, (v) => v + e.amount, ifAbsent: () => e.amount);
      byDay
          .putIfAbsent(FinanceCalculator.dayOf(e.date), () => <ExpenseItem>[])
          .add(e);
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, 'Expenses'),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in const ['All', 'Paid', 'Unpaid']) ...[
                    Expanded(
                      child: FinanceChip(
                        label: s,
                        selected: _status == s,
                        onTap: () => setState(() => _status = s),
                      ),
                    ),
                    if (s != 'Unpaid') const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              FinanceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Expenses',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          FinanceFormat.money(total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    if (categories.isNotEmpty) ...[
                      const Divider(height: 18),
                      ...categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                FinanceFormat.money(c.value),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FinanceEmpty(message: 'No expenses in this period.'),
                )
              else
                for (final day in days) ...[
                  FinanceDayHeader(
                    date: day,
                    trailing: FinanceFormat.money(
                      byDay[day]!.fold<double>(0, (s, e) => s + e.amount),
                    ),
                  ),
                  ...byDay[day]!.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ExpenseCard(item: e),
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

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.item});

  final ExpenseItem item;

  @override
  Widget build(BuildContext context) {
    final title = (item.expenseType?.trim().isNotEmpty ?? false)
        ? item.expenseType!.trim()
        : (item.description ?? 'Expense');
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseDetailsScreen(itemId: item.id),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  '${item.employeeName}  •  ${item.paymentType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FinanceFormat.money(item.amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item.isPaid ? 'Paid' : 'Unpaid',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: item.isPaid ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
