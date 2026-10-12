import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ExpenseAnalyticsScreen extends StatefulWidget {
  const ExpenseAnalyticsScreen({super.key, required this.items});

  final List<ExpenseItem> items;

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  String _mode = 'Monthly';
  String? _employeeFilter;
  DateTime? _selectedDate;

  List<ExpenseItem> get _filtered {
    var list = widget.items;
    if (_employeeFilter != null && _employeeFilter!.isNotEmpty) {
      list = list
          .where((item) => item.employeeName == _employeeFilter)
          .toList();
    }
    if (_selectedDate == null) return list;
    if (_mode == 'Weekly') {
      final start = _selectedDate!.subtract(
        Duration(days: _selectedDate!.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return list
          .where(
            (item) => !item.date.isBefore(start) && !item.date.isAfter(end),
          )
          .toList();
    }
    return list
        .where(
          (item) =>
              item.date.year == _selectedDate!.year &&
              item.date.month == _selectedDate!.month,
        )
        .toList();
  }

  double get _total => _filtered.fold(0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    final employees = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .map((e) => e.fullName)
        .toList();
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
          'Expense Analytics',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _modeChip('Weekly'),
                    const SizedBox(width: 8),
                    _modeChip('Monthly'),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _employeeFilter,
                  decoration: _decoration('Filter by Employee'),
                  icon: const Icon(CupertinoIcons.chevron_down, size: 15),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All Employees'),
                    ),
                    ...employees.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _employeeFilter = (value == null || value.isEmpty)
                          ? null
                          : value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    setState(() => _selectedDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _decoration('Calendar Date Filter'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : '${_selectedDate!.day.toString().padLeft(2, '0')}-'
                                      '${_selectedDate!.month.toString().padLeft(2, '0')}-'
                                      '${_selectedDate!.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const Icon(CupertinoIcons.calendar, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Filtered Total',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs.${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_filtered.length} transaction(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String mode) {
    final selected = _mode == mode;
    return Expanded(
      child: ChoiceChip(
        label: Text(mode),
        selected: selected,
        selectedColor: Colors.white,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.shade300,
        ),
        labelStyle: TextStyle(
          fontSize: 11.5,
          color: Colors.black,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        onSelected: (_) => setState(() => _mode = mode),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
