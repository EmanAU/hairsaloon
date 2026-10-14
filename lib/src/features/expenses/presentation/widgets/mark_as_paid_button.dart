import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
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
    final methods = context.read<SettingsStore>().paymentMethods;
    final payment = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => AppSheetBody(
        title: 'Mark as Paid',
        subtitle: 'Choose how this expense was paid.',
        showCancel: true,
        child: Column(
          children: [
            for (final method in methods)
              ListTile(
                title: Text(method),
                onTap: () => Navigator.of(sheetContext).pop(method),
              ),
          ],
        ),
      ),
    );
    if (payment == null || !context.mounted) return;
    try {
      await context.read<ExpensesStore>().markAsPaid(
        item.id,
        paymentType: payment,
      );
      ToastService.success('Marked as paid');
    } catch (_) {
      ToastService.error('Could not mark expense as paid. Please try again.');
    }
  }
}
