import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

/// Full-width highlighted action for unpaid expenses.
class MarkAsPaidButton extends StatelessWidget {
  const MarkAsPaidButton({super.key, required this.item});

  final ExpenseItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        onPressed: () => _markPaid(context),
        child: const Text('Mark as Paid'),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Mark as Paid',
      message: 'Confirm this expense has been paid?',
      confirmLabel: 'Mark Paid',
      icon: CupertinoIcons.checkmark_circle_fill,
    );
    if (ok != true || !context.mounted) return;
    await context.read<ExpensesStore>().markAsPaid(item.id);
    ToastService.success('Marked as paid');
  }
}
