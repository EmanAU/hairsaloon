import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ProfitDetailScreen extends StatefulWidget {
  const ProfitDetailScreen({super.key});

  @override
  State<ProfitDetailScreen> createState() => _ProfitDetailScreenState();
}

class _ProfitDetailScreenState extends State<ProfitDetailScreen> {
  FinancePeriod? _period;
  DateTime? _anchor;

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
    final bills = context.watch<BillingStore>().bills;
    final expenses = context.watch<ExpensesStore>().items;
    final payouts = context.watch<PayoutsStore>().payouts;

    final totals = FinanceCalculator.totals(
      bills: bills,
      expenses: expenses,
      payouts: payouts,
      anchor: anchor,
      period: period,
    );
    final days = FinanceCalculator.dailySummaries(
      bills: bills,
      expenses: expenses,
      payouts: payouts,
      anchor: anchor,
      period: period,
    );
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, 'Profit'),
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
              const SizedBox(height: 10),
              FinanceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _line('Sales', totals.sales, AppColors.textPrimary),
                    _line('Expenses', -totals.expenses, AppColors.danger),
                    _line('Settled Salaries', -totals.salaries, AppColors.danger),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Net Profit',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          FinanceFormat.money(totals.profit),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: totals.profit < 0
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const FinanceSectionTitle('Day-wise'),
              if (days.isEmpty)
                const FinanceEmpty(message: 'No activity in this period.')
              else
                ...days.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DayProfitTile(day: d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            FinanceFormat.money(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayProfitTile extends StatelessWidget {
  const _DayProfitTile({required this.day});

  final FinanceDaySummary day;

  @override
  Widget build(BuildContext context) {
    final positive = day.profit >= 0;
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  FinanceFormat.dayHeader(day.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                FinanceFormat.money(day.profit),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: positive ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell('Sales', day.sales, AppColors.textPrimary),
              _cell('Expenses', day.expenses, AppColors.danger),
              _cell('Salaries', day.salaries, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            FinanceFormat.money(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
