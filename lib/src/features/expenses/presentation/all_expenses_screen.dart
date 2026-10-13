import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_analytics_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class AllExpensesScreen extends StatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen> {
  String _status = 'All';
  String? _employee;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ExpensesStore>().reload();
    });
  }

  List<ExpenseItem> get _items => context.watch<ExpensesStore>().items;

  List<ExpenseItem> get _filtered {
    var list = _items;
    if (_status == 'Paid') {
      list = list.where((item) => item.isPaid).toList();
    } else if (_status == 'Unpaid') {
      list = list.where((item) => item.isUnpaid).toList();
    }
    if (_employee != null && _employee!.isNotEmpty) {
      list = list.where((item) => item.employeeName == _employee).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final employees = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .map((e) => e.fullName)
        .toList();
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
          'All Transactions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpenseAnalyticsScreen(items: _items),
                ),
              );
            },
            icon: const Icon(
              CupertinoIcons.chart_bar_fill,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              _chip('All'),
              const SizedBox(width: 8),
              _chip('Paid'),
              const SizedBox(width: 8),
              _chip('Unpaid'),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _employee,
            decoration: _decoration('Filter by Employee'),
            icon: const Icon(CupertinoIcons.chevron_down, size: 15),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Employees')),
              ...employees.map(
                (e) => DropdownMenuItem(value: e, child: Text(e)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _employee = (value == null || value.isEmpty) ? null : value;
              });
            },
          ),
          const SizedBox(height: 10),
          ..._filtered.map(_tile),
        ],
      ),
    );
  }

  Widget _chip(String value) {
    final selected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(ExpenseItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.status}  •  ${item.expenseType ?? item.description ?? '-'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isPaid
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs.${item.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () async {
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
                  },
                  icon: const Icon(
                    CupertinoIcons.delete,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (item.isUnpaid)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await showAppConfirmDialog(
                    context: context,
                    title: 'Mark as Paid',
                    message: 'Confirm this expense has been paid?',
                    confirmLabel: 'Mark Paid',
                  );
                  if (ok != true || !mounted) return;
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
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
