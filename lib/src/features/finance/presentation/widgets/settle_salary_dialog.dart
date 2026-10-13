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

enum _ExtraMode { amount, percent }

/// Shows the settlement breakdown; returns null when cancelled.
Future<SettleSalaryResult?> showSettleSalaryDialog({
  required BuildContext context,
  required String employeeName,
  required List<EmployeeDayIncome> days,
  required double salesTotal,
  required double commissionPercent,
}) {
  final due = days.where((d) => d.dueAmount > 0).toList();
  if (due.isEmpty) return Future.value(null);
  due.sort((a, b) => a.date.compareTo(b.date));

  double round2(double v) => double.parse(v.toStringAsFixed(2));
  final earning = round2(due.fold<double>(0, (s, d) => s + d.earning));
  final cut = round2(due.fold<double>(0, (s, d) => s + d.paidAmount));
  final pay = round2(due.fold<double>(0, (s, d) => s + d.dueAmount));
  final sales = round2(due.fold<double>(0, (s, d) => s + d.sales));
  final dateText = due.length == 1
      ? FinanceFormat.date(due.first.date)
      : '${FinanceFormat.date(due.first.date)} - ${FinanceFormat.date(due.last.date)}';

  return showAppSheet<SettleSalaryResult>(
    context: context,
    builder: (_) => _SettleSheet(
      employeeName: employeeName,
      dateText: dateText,
      dayCount: due.length,
      salesTotal: sales > 0 ? sales : salesTotal,
      commissionPercent: commissionPercent,
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
    required this.salesTotal,
    required this.commissionPercent,
    required this.earning,
    required this.cut,
    required this.pay,
  });

  final String employeeName;
  final String dateText;
  final int dayCount;
  final double salesTotal;
  final double commissionPercent;
  final double earning;
  final double cut;
  final double pay;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  final _noteCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _baseFocus = FocusNode();
  _ExtraMode _extraMode = _ExtraMode.amount;
  bool _bonusConfirmed = false;
  String? _error;

  double get _base => double.tryParse(_baseCtrl.text.trim()) ?? 0;
  double get _extraInput => double.tryParse(_extraCtrl.text.trim()) ?? 0;

  double get _extraAmount {
    if (_extraInput <= 0) return 0;
    if (_extraMode == _ExtraMode.percent) {
      return double.parse(
        (widget.salesTotal * _extraInput / 100).toStringAsFixed(2),
      );
    }
    return double.parse(_extraInput.toStringAsFixed(2));
  }

  double get _due => double.parse(widget.pay.toStringAsFixed(2));

  double get _total =>
      double.parse((_base + _extraAmount).toStringAsFixed(2));

  /// Only treat clear overpay as tip; ignore float noise under 1 paisa.
  double get _bonus {
    final excess = double.parse((_total - _due).toStringAsFixed(2));
    return excess > 0 ? excess : 0;
  }

  static String _formatSeed(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _baseCtrl.text = _formatSeed(_due);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _baseFocus.requestFocus();
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) return;
      void listener(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(listener);
        if (mounted) _baseFocus.requestFocus();
      }

      animation.addStatusListener(listener);
    });
  }

  void _onChanged() {
    setState(() {
      _error = null;
      _bonusConfirmed = false;
    });
  }

  void _confirm() {
    final baseText = _baseCtrl.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(baseText) ||
        !_base.isFinite ||
        _base < 0) {
      setState(
        () => _error =
            'Enter a valid base amount with up to 2 decimal places.',
      );
      return;
    }
    final extraText = _extraCtrl.text.trim();
    if (extraText.isNotEmpty) {
      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(extraText) ||
          !_extraInput.isFinite ||
          _extraInput < 0) {
        setState(
          () => _error =
              'Enter a valid extra value with up to 2 decimal places.',
        );
        return;
      }
    }
    if (!_total.isFinite || _total <= 0) {
      setState(() => _error = 'Enter a positive payment total.');
      return;
    }
    if (_bonus > 0 && !_bonusConfirmed) {
      setState(() => _error = 'Confirm the extra amount as a bonus/tip.');
      return;
    }
    Navigator.of(context).pop(
      SettleSalaryResult(
        amount: _total,
        bonusConfirmed: _bonusConfirmed,
        note: _noteCtrl.text,
      ),
    );
  }

  @override
  void dispose() {
    _baseFocus.dispose();
    _baseCtrl.dispose();
    _extraCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingAfter = _total < _due
        ? double.parse((_due - _total).toStringAsFixed(2))
        : 0.0;

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
                _line('Sales', FinanceFormat.money(widget.salesTotal)),
                _line(
                  'Commission %',
                  '${widget.commissionPercent.toStringAsFixed(
                    widget.commissionPercent ==
                            widget.commissionPercent.roundToDouble()
                        ? 0
                        : 1,
                  )}%',
                ),
                _line('Earning', FinanceFormat.money(widget.earning)),
                _line('Already paid', FinanceFormat.money(widget.cut)),
                const Divider(height: 18, color: AppColors.border),
                _line(
                  'Remaining due',
                  FinanceFormat.money(_due),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseCtrl,
            focusNode: _baseFocus,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            decoration: appSheetInputDecoration('Base payment').copyWith(
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
            onChanged: (_) => _onChanged(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Extra tip/bonus (optional)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Amount',
                  selected: _extraMode == _ExtraMode.amount,
                  onTap: () => setState(() {
                    _extraMode = _ExtraMode.amount;
                    _bonusConfirmed = false;
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Percent',
                  selected: _extraMode == _ExtraMode.percent,
                  onTap: () => setState(() {
                    _extraMode = _ExtraMode.percent;
                    _bonusConfirmed = false;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _extraCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: appSheetInputDecoration(
              _extraMode == _ExtraMode.percent
                  ? 'Extra percent of sales'
                  : 'Extra amount',
              suffixIcon: _extraMode == _ExtraMode.percent
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            onSubmitted: (_) => _confirm(),
            onChanged: (_) => _onChanged(),
          ),
          if (_extraAmount > 0) ...[
            const SizedBox(height: 8),
            _line(
              'Extra tip/bonus',
              FinanceFormat.money(_extraAmount),
              color: AppColors.success,
              emphasize: true,
            ),
          ],
          const SizedBox(height: 10),
          _line(
            'Payment total',
            FinanceFormat.money(_total),
            emphasize: true,
          ),
          _line(
            'Remaining after payment',
            FinanceFormat.money(remainingAfter),
            emphasize: true,
          ),
          if (_bonus > 0) ...[
            _line(
              'Recorded as bonus/tip',
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
            'Shop expenses and tax are not deducted from employee earnings. Fixed salary is settled separately.',
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.surface : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
