import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';

class FinanceFormat {
  const FinanceFormat._();

  static const _monthsShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String money(double value) {
    final whole = value.abs().toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return value < 0 ? '-Rs.$whole' : 'Rs.$whole';
  }

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthsShort[d.month - 1]} ${d.year}';

  static String dayHeader(DateTime d) {
    final today = FinanceCalculator.dayOf(DateTime.now());
    final day = FinanceCalculator.dayOf(d);
    if (day == today) return 'Today, ${date(d)}';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${date(d)}';
    }
    return '${_weekdays[d.weekday - 1]}, ${date(d)}';
  }

  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String periodLabel(DateTime anchor, FinancePeriod period) {
    switch (period) {
      case FinancePeriod.daily:
        return date(anchor);
      case FinancePeriod.weekly:
        final start = FinanceCalculator.weekStart(anchor);
        return '${date(start)} - ${date(start.add(const Duration(days: 6)))}';
      case FinancePeriod.monthly:
        return '${_monthsShort[anchor.month - 1]} ${anchor.year}';
    }
  }

  static String periodWord(FinancePeriod period) {
    switch (period) {
      case FinancePeriod.daily:
        return 'Today';
      case FinancePeriod.weekly:
        return 'This Week';
      case FinancePeriod.monthly:
        return 'This Month';
    }
  }
}
