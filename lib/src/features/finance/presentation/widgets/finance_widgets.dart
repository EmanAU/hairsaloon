import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
];

/// Passed to finance sub pages so they open on the same period.
class FinanceRouteArgs {
  const FinanceRouteArgs({required this.anchor, required this.period});

  final DateTime anchor;
  final FinancePeriod period;

  static FinanceRouteArgs of(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is FinanceRouteArgs) return args;
    return FinanceRouteArgs(
      anchor: DateTime.now(),
      period: FinancePeriod.daily,
    );
  }
}

/// Yellow app bar used by finance sub pages.
PreferredSizeWidget financeAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.primary,
    surfaceTintColor: const Color(0x00000000),
    leading: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
    ),
    title: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Daily / Weekly / Monthly chips with a date picker button.
class FinancePeriodBar extends StatelessWidget {
  const FinancePeriodBar({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  final FinancePeriod period;
  final DateTime anchor;
  final ValueChanged<FinancePeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final entry in const {
              FinancePeriod.daily: 'Daily',
              FinancePeriod.weekly: 'Weekly',
              FinancePeriod.monthly: 'Monthly',
            }.entries) ...[
              Expanded(
                child: FinanceChip(
                  label: entry.value,
                  selected: period == entry.key,
                  onTap: () => onPeriodChanged(entry.key),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.calendar,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    FinanceFormat.periodLabel(anchor, period),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FinanceChip extends StatelessWidget {
  const FinanceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.textPrimary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.surface : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small stat card: icon, label, amount.
class FinanceStatCard extends StatelessWidget {
  const FinanceStatCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _cardShadow,
            color: AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 13, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  FinanceFormat.money(amount),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain white rounded card.
class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class FinanceDayHeader extends StatelessWidget {
  const FinanceDayHeader({
    super.key,
    required this.date,
    required this.trailing,
  });

  final DateTime date;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              FinanceFormat.dayHeader(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceEmpty extends StatelessWidget {
  const FinanceEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class FinanceSectionTitle extends StatelessWidget {
  const FinanceSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({super.key, required this.employee, this.radius = 20});

  final EmployeeItem employee;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = employee.photoBase64;
    if (photo != null && photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(photo)),
        );
      } catch (_) {
        // fall through to initials
      }
    }
    final parts = employee.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
              .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.35),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
