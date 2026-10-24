import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'widgets/payment_method_tiles.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    this.suppliedBills,
    this.title = 'Sales',
    this.commissionByBill = const {},
    this.onOpenBill,
    this.employeeView = false,
  });
  final List<Bill>? suppliedBills;
  final String title;
  final Map<String, double> commissionByBill;
  final ValueChanged<Bill>? onOpenBill;
  final bool employeeView;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<String> get _payments => {
    'All',
    'Cash',
    'Card',
    'Online',
    ...(widget.suppliedBills ?? context.read<BillingStore>().bills)
        .map((b) => b.paymentType)
        .where((p) => p.isNotEmpty),
  }.toList();

  FinancePeriod? _period;
  DateTime? _anchor;
  Set<String> _paymentsSelected = {};

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
    final bills = (widget.suppliedBills ?? context.watch<BillingStore>().bills)
        .where(
          (b) => FinanceCalculator.periodContains(b.createdAt, anchor, period),
        )
        .where(
          (b) => PaymentMethodTiles.matches(b.paymentType, _paymentsSelected),
        )
        .toList(growable: false);

    final total = bills.fold<double>(0, (s, b) => s + b.grandTotal);
    final average = bills.isEmpty ? 0.0 : total / bills.length;

    final byDay = <DateTime, List<Bill>>{};
    for (final b in bills) {
      byDay
          .putIfAbsent(FinanceCalculator.dayOf(b.createdAt), () => <Bill>[])
          .add(b);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: financeAppBar(context, widget.title),
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
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FinanceStatCard(
                        title: 'Total Sales',
                        amount: total,
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        color: AppColors.textPrimary,
                        subtitle:
                            '${bills.length} ${bills.length == 1 ? 'bill' : 'bills'}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FinanceStatCard(
                        title: 'Average Bill',
                        amount: average,
                        icon: CupertinoIcons.doc_text,
                        color: AppColors.success,
                        subtitle: FinanceFormat.periodWord(period),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PaymentMethodTiles(
                methods: _payments.where((p) => p != 'All'),
                selected: _paymentsSelected,
                onChanged: (value) => setState(() => _paymentsSelected = value),
              ),
              if (widget.employeeView) ...[
                const SizedBox(height: 12),
                FinanceStatCard(
                  title: 'Your commission',
                  amount: bills.fold<double>(
                    0,
                    (sum, bill) =>
                        sum + (widget.commissionByBill[bill.id] ?? 0),
                  ),
                  icon: CupertinoIcons.money_dollar_circle,
                  color: AppColors.homeOlive,
                  subtitle: 'Original service price · tax excluded',
                ),
              ],
              const SizedBox(height: 12),
              FinanceSectionTitle(
                'Recent Sales',
                trailing: Text(
                  '${bills.length} ${bills.length == 1 ? 'bill' : 'bills'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (days.isEmpty)
                const FinanceEmpty(message: 'No sales for these filters.')
              else
                for (final day in days) ...[
                  FinanceDayHeader(
                    date: day,
                    trailing: FinanceFormat.money(
                      byDay[day]!.fold<double>(0, (s, b) => s + b.grandTotal),
                    ),
                  ),
                  ...byDay[day]!.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _SaleTile(
                        bill: b,
                        onTap: widget.onOpenBill == null
                            ? null
                            : () => widget.onOpenBill!(b),
                      ),
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

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.bill, this.onTap});
  final VoidCallback? onTap;

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final name = bill.customerName.trim();
    final phone = PkPhone.localNumber(bill.customerPhone);
    final customer = name.isNotEmpty
        ? name
        : (phone.isNotEmpty ? phone : 'Walk-in Customer');
    final services = bill.lines.map((l) => l.serviceName).join(', ');
    final meta = [
      FinanceFormat.time(bill.createdAt),
      if (bill.paymentType.trim().isNotEmpty) bill.paymentType.trim(),
      if (bill.employeeName.trim().isNotEmpty) bill.employeeName.trim(),
    ].join('  •  ');

    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap:
          onTap ??
          () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.billDetails, arguments: bill.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (services.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    services,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FinanceFormat.money(bill.grandTotal),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
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
