import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class SettleSalaryResult {
  const SettleSalaryResult({this.note});

  final String? note;
}

/// Shows the settlement breakdown; returns null when cancelled.
Future<SettleSalaryResult?> showSettleSalaryDialog({
  required BuildContext context,
  required String employeeName,
  required List<EmployeeDayIncome> days,
}) {
  final due = days.where((d) => !d.isSettled && d.payableAmount > 0).toList();
  if (due.isEmpty) return Future.value(null);
  due.sort((a, b) => a.date.compareTo(b.date));

  final earning = due.fold<double>(0, (s, d) => s + d.earning);
  final cut = due.fold<double>(0, (s, d) => s + d.expenseCut);
  final pay = due.fold<double>(0, (s, d) => s + d.payableAmount);
  final dateText = due.length == 1
      ? FinanceFormat.date(due.first.date)
      : '${FinanceFormat.date(due.first.date)} - ${FinanceFormat.date(due.last.date)}';

  return showAppSheet<SettleSalaryResult>(
    context: context,
    builder: (_) => _SettleSheet(
      employeeName: employeeName,
      dateText: dateText,
      dayCount: due.length,
      earning: earning,
      cut: cut,
      pay: pay,
    ),
  );
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({
    required this.employeeName,
    required this.dateText,
    required this.dayCount,
    required this.earning,
    required this.cut,
    required this.pay,
  });

  final String employeeName;
  final String dateText;
  final int dayCount;
  final double earning;
  final double cut;
  final double pay;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Settle Salary',
      subtitle: widget.employeeName,
      icon: CupertinoIcons.checkmark_seal,
      iconColor: AppColors.success,
      confirmLabel: 'Confirm Settle',
      onConfirm: () =>
          Navigator.of(context).pop(SettleSalaryResult(note: _noteCtrl.text)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _line(
                  widget.dayCount == 1 ? 'Date' : 'Days',
                  widget.dayCount == 1
                      ? widget.dateText
                      : '${widget.dayCount} days',
                ),
                if (widget.dayCount > 1) _line('Range', widget.dateText),
                _line('Earning', FinanceFormat.money(widget.earning)),
                _line(
                  'Expense cut',
                  '- ${FinanceFormat.money(widget.cut)}',
                  color: widget.cut > 0
                      ? AppColors.danger
                      : AppColors.textPrimary,
                ),
                const Divider(height: 18, color: AppColors.border),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Amount to pay',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      FinanceFormat.money(widget.pay),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 13),
            decoration: appSheetInputDecoration('Note (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
