import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_details_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ExpensesStore>().reload();
    });
  }

  Map<String, List<ExpenseItem>> _groupByMonth(List<ExpenseItem> items) {
    final map = <String, List<ExpenseItem>>{};
    for (final item in items) {
      final key =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => <ExpenseItem>[]).add(item);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  String _monthTitle(String key) {
    final parts = key.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? 1;
    return '${_months[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ExpensesStore>().items;
    final grouped = _groupByMonth(items);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Expenses History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 720 : double.infinity),
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No expenses yet.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final key = grouped.keys.elementAt(index);
                    final monthItems = grouped[key]!;
                    final total = monthItems.fold<double>(
                      0,
                      (sum, e) => sum + e.amount,
                    );
                    final paid = monthItems.where((e) => e.isPaid).length;
                    final unpaid = monthItems.length - paid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: const Color(0x00000000)),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            10,
                            0,
                            10,
                            12,
                          ),
                          title: Text(
                            _monthTitle(key),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${monthItems.length} expenses  •  '
                              'Paid $paid  •  Unpaid $unpaid',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          trailing: Text(
                            'Rs.${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          children: monthItems
                              .map((item) => _HistoryTile(item: item))
                              .toList(growable: false),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final ExpenseItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isPaid
        ? AppColors.success
        : AppColors.danger;
    final date =
        '${item.date.day.toString().padLeft(2, '0')}-'
        '${item.date.month.toString().padLeft(2, '0')}-${item.date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpenseDetailsScreen(itemId: item.id),
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.expenseType?.trim().isNotEmpty == true
                            ? item.expenseType!
                            : (item.description ?? 'Expense'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$date  •  ${item.employeeName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.status} (${item.paymentType})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs.${item.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (item.isUnpaid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await showAppConfirmDialog(
                    context: context,
                    title: 'Mark as Paid',
                    message:
                        'Mark this expense as paid? You can still edit later.',
                    confirmLabel: 'Mark Paid',
                  );
                  if (ok != true || !context.mounted) return;
                  await context.read<ExpensesStore>().markAsPaid(item.id);
                  ToastService.success('Marked as paid');
                },
                icon: const Icon(CupertinoIcons.checkmark_circle, size: 16),
                label: const Text(
                  'Mark as Paid',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
