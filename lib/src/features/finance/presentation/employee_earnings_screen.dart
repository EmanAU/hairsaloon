import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeEarningsScreen extends StatefulWidget {
  const EmployeeEarningsScreen({super.key});

  @override
  State<EmployeeEarningsScreen> createState() => _EmployeeEarningsScreenState();
}

class _EmployeeEarningsScreenState extends State<EmployeeEarningsScreen> {
  _EarningPeriod _period = _EarningPeriod.monthly;
  DateTime _anchorDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final employees = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .toList(growable: false);
    final bills = context.watch<BillingStore>().bills;

    final rows = employees.map((employee) {
      final employeeSales = bills
          .where(
            (bill) =>
                bill.employeeName == employee.fullName &&
                _isInPeriod(bill.createdAt),
          )
          .fold<double>(0, (sum, bill) => sum + bill.grandTotal);
      final salary = _toDouble(employee.basicSalary);
      final commissionPercent = _toDouble(employee.commission);
      final commissionAmount = (employeeSales * commissionPercent) / 100;
      final totalPayout = salary + commissionAmount;
      return _EmployeeEarning(
        employee: employee,
        sales: employeeSales,
        salary: salary,
        commissionPercent: commissionPercent,
        commissionAmount: commissionAmount,
        totalPayout: totalPayout,
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Employee Earnings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(CupertinoIcons.calendar, color: Colors.black),
          ),
        ],
      ),
      body: rows.isEmpty
          ? const Center(child: Text('No employees found.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _periodRow(),
                const SizedBox(height: 10),
                ...rows.map(_earningCard),
              ],
            ),
    );
  }

  bool _isInPeriod(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    switch (_period) {
      case _EarningPeriod.daily:
        return target ==
            DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
      case _EarningPeriod.weekly:
        final start = _weekStart(_anchorDate);
        final end = start.add(const Duration(days: 6));
        return !target.isBefore(start) && !target.isAfter(end);
      case _EarningPeriod.monthly:
        return target.year == _anchorDate.year &&
            target.month == _anchorDate.month;
    }
  }

  DateTime _weekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _anchorDate = picked);
  }

  Widget _periodRow() {
    return Row(
      children: [
        _periodChip(_EarningPeriod.daily, 'Daily'),
        const SizedBox(width: 8),
        _periodChip(_EarningPeriod.weekly, 'Weekly'),
        const SizedBox(width: 8),
        _periodChip(_EarningPeriod.monthly, 'Monthly'),
      ],
    );
  }

  Widget _periodChip(_EarningPeriod period, String label) {
    final selected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = period),
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
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final normalized = value.replaceAll(',', '').replaceAll('%', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Widget _earningCard(_EmployeeEarning row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.employee.fullName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: row.employee.isActive
                        ? const Color(0xFF46A758)
                        : const Color(0xFFB0B0B0),
                  ),
                ),
                child: Text(
                  row.employee.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: row.employee.isActive
                        ? const Color(0xFF2B7A3A)
                        : const Color(0xFF6B6B6B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line('Sales', 'Rs.${row.sales.toStringAsFixed(0)}'),
          _line('Basic Salary', 'Rs.${row.salary.toStringAsFixed(0)}'),
          _line('Commission %', '${row.commissionPercent.toStringAsFixed(0)}%'),
          _line(
            'Commission Amount',
            'Rs.${row.commissionAmount.toStringAsFixed(0)}',
          ),
          const Divider(height: 14),
          _line(
            'Total Payout',
            'Rs.${row.totalPayout.toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeEarning {
  const _EmployeeEarning({
    required this.employee,
    required this.sales,
    required this.salary,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.totalPayout,
  });

  final EmployeeItem employee;
  final double sales;
  final double salary;
  final double commissionPercent;
  final double commissionAmount;
  final double totalPayout;
}

enum _EarningPeriod { daily, weekly, monthly }
