import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/all_expenses_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_details_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_history_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_types_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/widgets/mark_as_paid_button.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _statusFilter = 'Paid';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ExpensesStore>().reload();
    });
  }

  List<ExpenseItem> get _items => context.watch<ExpensesStore>().items;

  List<ExpenseItem> get _filteredItems {
    return _items
        .where((item) => _statusFilter == 'Paid' ? item.isPaid : item.isUnpaid)
        .toList(growable: false);
  }

  double get _monthlyTotal {
    final now = DateTime.now();
    return _items
        .where(
          (item) => item.date.year == now.year && item.date.month == now.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get _todayTotal {
    final now = DateTime.now();
    return _items
        .where(
          (item) =>
              item.date.year == now.year &&
              item.date.month == now.month &&
              item.date.day == now.day,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  Future<void> _addExpense() async {
    final created = await Navigator.of(context).push<ExpenseItem>(
      MaterialPageRoute(builder: (_) => const ExpenseTypesScreen()),
    );
    if (created == null || !mounted) return;
    await context.read<ExpensesStore>().add(created);
    if (!mounted) return;
    ToastService.success('Expense added');
  }

  Future<void> _deleteExpense(ExpenseItem item) async {
    final shouldDelete = await showAppConfirmDialog(
      context: context,
      title: 'Delete Expense',
      message: 'Are you sure you want to delete this expense?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (shouldDelete != true || !mounted) return;
    await context.read<ExpensesStore>().delete(item.id);
    ToastService.success('Expense deleted');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final bottomPad = bottomInset + (tablet ? 24 : 110);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
        children: [
          _buildHeaderWithTodayCard(context),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildFilters(),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  _statusFilter == 'Paid'
                      ? 'Paid Transactions'
                      : 'Unpaid Transactions',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AllExpensesScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filteredItems.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 24, 12, 12),
              child: Center(
                child: Text(
                  'No transactions in this filter.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ..._filteredItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _expenseTile(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithTodayCard(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    const overlapHeight = 86.0;
    const totalToTodayGap = 20.0;
    final yellowHeight = topInset + 220;

    return SizedBox(
      height: yellowHeight + overlapHeight + totalToTodayGap,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: yellowHeight,
            child: Container(
              color: AppColors.primary,
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Expenses',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Expenses History',
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.expenseHistory);
                        },
                        icon: const Icon(
                          CupertinoIcons.calendar,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Total Monthly Expenses',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rs.${_monthlyTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: yellowHeight - overlapHeight + totalToTodayGap,
            child: _buildTodayCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Today Expenses',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            'Rs.${_todayTotal.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _addExpense,
                    icon: const Icon(CupertinoIcons.add_circled, size: 14),
                    label: const Text(
                      'Add New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFD8D8D8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpenseHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(CupertinoIcons.time, size: 14),
                    label: const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _filterChip('Paid'),
        const SizedBox(width: 8),
        _filterChip('Unpaid'),
      ],
    );
  }

  Widget _filterChip(String status) {
    final selected = _statusFilter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            ),
          ),
          child: Center(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _expenseTile(ExpenseItem item) {
    final statusColor = item.isPaid ? AppColors.success : AppColors.danger;
    final date =
        '${item.date.day.toString().padLeft(2, '0')}-'
        '${item.date.month.toString().padLeft(2, '0')}-${item.date.year}';
    final time =
        '${item.createdAt.hour.toString().padLeft(2, '0')}:'
        '${item.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpenseDetailsScreen(itemId: item.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    '$time\n$date',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${item.paymentType})',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description ??
                            item.expenseType ??
                            'No description',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs.${item.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteExpense(item),
                  icon: const Icon(
                    CupertinoIcons.delete,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  splashRadius: 16,
                ),
              ],
            ),
          ),
          if (item.isUnpaid) ...[
            const Divider(height: 16, color: AppColors.border),
            MarkAsPaidButton(item: item),
          ],
        ],
      ),
    );
  }
}
