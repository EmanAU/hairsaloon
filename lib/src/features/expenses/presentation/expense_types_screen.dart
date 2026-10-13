import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ExpenseTypesScreen extends StatefulWidget {
  const ExpenseTypesScreen({super.key});

  @override
  State<ExpenseTypesScreen> createState() => _ExpenseTypesScreenState();
}

class _ExpenseTypesScreenState extends State<ExpenseTypesScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  String? _selectedEmployee;
  String? _selectedExpenseType;
  String? _selectedStatus;
  String? _selectedPaymentType;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();

  static const List<String> _expenseTypes = [
    'Utilities',
    'Supplies',
    'Maintenance',
    'Tea/Coffee',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _quantityCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

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
          'Add Expense',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _dateField(context),
                  const SizedBox(height: 8),
                  _dropdownField(
                    value: _selectedEmployee,
                    hint: 'Select Employee',
                    items: employees,
                    requiredField: true,
                    onChanged: (value) =>
                        setState(() => _selectedEmployee = value),
                  ),
                  const SizedBox(height: 8),
                  _dropdownField(
                    value: _selectedExpenseType,
                    hint: 'Select Expense Type',
                    items: _expenseTypes,
                    onChanged: (value) =>
                        setState(() => _selectedExpenseType = value),
                  ),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _amountCtrl,
                    hint: 'Enter Amount',
                    keyboardType: TextInputType.number,
                    requiredField: true,
                  ),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _quantityCtrl,
                    hint: 'Quantity',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _dropdownField(
                    value: _selectedStatus,
                    hint: 'Status (Paid or Unpaid)',
                    items: const ['Paid', 'Unpaid'],
                    onChanged: (value) =>
                        setState(() => _selectedStatus = value),
                  ),
                  const SizedBox(height: 8),
                  _dropdownField(
                    value: _selectedPaymentType,
                    hint: 'Payment Type (Cash or Online)',
                    items: const ['Cash', 'Online'],
                    onChanged: (value) =>
                        setState(() => _selectedPaymentType = value),
                  ),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _descriptionCtrl,
                    hint: 'Description',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveExpense,
                      child: const Text(
                        'Save Expense',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(BuildContext context) {
    final label = _selectedDate == null
        ? 'Select Date'
        : '${_selectedDate!.day.toString().padLeft(2, '0')}-'
              '${_selectedDate!.month.toString().padLeft(2, '0')}-'
              '${_selectedDate!.year}';
    return InkWell(
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
        decoration: _inputDecoration('Select Date'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_down, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool requiredField = false,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      style: const TextStyle(fontFamily: 'Roboto', 
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      decoration: _inputDecoration(hint),
      icon: const Icon(
        CupertinoIcons.chevron_down,
        size: 15,
        color: Colors.black,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: requiredField
          ? (value) => value == null ? 'Required' : null
          : null,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      decoration: _inputDecoration(hint),
      validator: requiredField
          ? (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  InputDecoration _inputDecoration(String hint) {
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

  void _saveExpense() {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;
    if (_selectedDate == null) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null) return;

    final expense = ExpenseItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate!,
      employeeName: _selectedEmployee!,
      amount: amount,
      status: ExpenseItem.normalizeStatus(_selectedStatus ?? 'Paid'),
      paymentType: _selectedPaymentType ?? 'Cash',
      expenseType: _selectedExpenseType,
      quantity: int.tryParse(_quantityCtrl.text.trim()),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop(expense);
  }
}
