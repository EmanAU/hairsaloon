import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class SettleSalaryResult {
  const SettleSalaryResult({
    required this.amount,
    required this.bonusConfirmed,
    this.note,
  });

  final double amount;
  final bool bonusConfirmed;

  final String? note;
}

/// Shows the settlement breakdown; returns null when cancelled.
Future<SettleSalaryResult?> showSettleSalaryDialog({
  required BuildContext context,
  required String employeeName,
  required List<EmployeeDayIncome> days,
}) {
  final due = days.where((d) => d.dueAmount > 0).toList();
  if (due.isEmpty) return Future.value(null);
  due.sort((a, b) => a.date.compareTo(b.date));

  final earning = due.fold<double>(0, (s, d) => s + d.earning);
  final cut = due.fold<double>(0, (s, d) => s + d.paidAmount);
  final pay = due.fold<double>(0, (s, d) => s + d.dueAmount);
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
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  bool _bonusConfirmed = false;
  String? _error;
  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  double get _bonus => _amount > widget.pay ? _amount - widget.pay : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _amountFocus.requestFocus();
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) return;
      void listener(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(listener);
        if (mounted) _amountFocus.requestFocus();
      }

      animation.addStatusListener(listener);
    });
  }

  void _confirm() {
    final text = _amountCtrl.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        !_amount.isFinite ||
        _amount <= 0) {
      setState(
        () => _error = 'Enter a positive amount with up to 2 decimal places.',
      );
      return;
    }
    if (_bonus > 0 && !_bonusConfirmed) {
      setState(() => _error = 'Confirm the extra amount as a bonus/tip.');
      return;
    }
    Navigator.of(context).pop(
      SettleSalaryResult(
        amount: _amount,
        bonusConfirmed: _bonusConfirmed,
        note: _noteCtrl.text,
      ),
    );
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Settle Up',
      confirmLabel: 'Record Payment',
      onConfirm: _confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.employeeName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
                _line('Already paid', FinanceFormat.money(widget.cut)),
                const Divider(height: 18, color: AppColors.border),
                _line(
                  'Remaining due',
                  FinanceFormat.money(widget.pay),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            focusNode: _amountFocus,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            decoration: appSheetInputDecoration('Payment amount').copyWith(
              errorText: _error,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              floatingLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            onSubmitted: (_) => _confirm(),
            onChanged: (_) => setState(() {
              _error = null;
              _bonusConfirmed = false;
            }),
          ),
          const SizedBox(height: 10),
          _line(
            'Remaining after payment',
            FinanceFormat.money(
              _amount < widget.pay ? widget.pay - _amount : 0,
            ),
            emphasize: true,
          ),
          if (_bonus > 0) ...[
            _line(
              'Extra bonus/tip',
              FinanceFormat.money(_bonus),
              color: AppColors.success,
              emphasize: true,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Confirm extra amount as bonus/tip',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              value: _bonusConfirmed,
              onChanged: (value) => setState(() {
                _bonusConfirmed = value ?? false;
                _error = null;
              }),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Shop expenses and tax are not deducted from employee earnings.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
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

  Widget _line(
    String label,
    String value, {
    Color? color,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: emphasize ? 16 : 12.5,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
