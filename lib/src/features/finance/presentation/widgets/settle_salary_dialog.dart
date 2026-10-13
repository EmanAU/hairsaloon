import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  return showDialog<SettleSalaryResult>(
    context: context,
    builder: (dialogContext) =>
        _SettleDialog(
          employeeName: employeeName,
          dateText: dateText,
          dayCount: due.length,
          earning: earning,
          cut: cut,
          pay: pay,
        ),
  );
}

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({
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
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: const Color(0x00000000),
        insetPadding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + media.viewInsets.bottom,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_seal,
                        color: AppColors.success,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Settle Salary',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                      if (widget.dayCount > 1)
                        _line('Range', widget.dateText),
                      _line('Earning', FinanceFormat.money(widget.earning)),
                      _line(
                        'Expense cut',
                        '- ${FinanceFormat.money(widget.cut)}',
                        color: widget.cut > 0
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                      const Divider(height: 18),
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
                              fontSize: 18,
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
                  decoration: InputDecoration(
                    hintText: 'Note (optional)',
                    hintStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.textPrimary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: Color(0xFFD8D8D8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(SettleSalaryResult(note: _noteCtrl.text)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Confirm Settle',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
