import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/widgets/mark_as_paid_button.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ExpenseDetailsScreen extends StatelessWidget {
  const ExpenseDetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final item = context.watch<ExpensesStore>().getById(itemId);
    if (item == null) {
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
            'Expense Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(child: Text('Expense not found.')),
      );
    }

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
          'Expense Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _row('Date', _formatDate(item.date)),
          _row('Employee', item.employeeName),
          _row('Amount', 'Rs.${item.amount.toStringAsFixed(0)}'),
          _row('Status', item.status),
          _row('Payment', item.isUnpaid ? 'Not paid' : item.paymentType),
          _row('Expense Type', item.expenseType ?? '-'),
          _row('Quantity', item.quantity?.toString() ?? '-'),
          _row('Description', item.description ?? '-'),
          if (item.isUnpaid) ...[
            const SizedBox(height: 12),
            MarkAsPaidButton(item: item),
          ],
          if (item.isPaid) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFD0D0D0)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final ok = await showAppConfirmDialog(
                  context: context,
                  title: 'Mark as Unpaid',
                  message: 'Move this expense back to unpaid?',
                  confirmLabel: 'Mark Unpaid',
                );
                if (ok != true || !context.mounted) return;
                await context.read<ExpensesStore>().markAsUnpaid(item.id);
                ToastService.success('Marked as unpaid');
              },
              icon: const Icon(CupertinoIcons.money_dollar_circle, size: 18),
              label: const Text(
                'Mark as Unpaid',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
