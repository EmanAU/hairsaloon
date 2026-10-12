import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class EmployeeAgreementScreen extends StatefulWidget {
  const EmployeeAgreementScreen({super.key, this.employee});

  final EmployeeItem? employee;

  @override
  State<EmployeeAgreementScreen> createState() =>
      _EmployeeAgreementScreenState();
}

class _EmployeeAgreementScreenState extends State<EmployeeAgreementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeTypeCtrl;
  late final TextEditingController _basicSalaryCtrl;
  late final TextEditingController _commissionCtrl;
  late final TextEditingController _descriptionCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _employeeTypeCtrl = TextEditingController(
      text: widget.employee?.employeeType ?? '',
    );
    _basicSalaryCtrl = TextEditingController(
      text: widget.employee?.basicSalary ?? '',
    );
    _commissionCtrl = TextEditingController(
      text: widget.employee?.commission ?? '',
    );
    _descriptionCtrl = TextEditingController(
      text: widget.employee?.agreementDescription ?? '',
    );
  }

  @override
  void dispose() {
    _employeeTypeCtrl.dispose();
    _basicSalaryCtrl.dispose();
    _commissionCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = widget.employee?.fullName ?? 'Employee';
    return AdaptivePage(
      form: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3),
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.back, color: Colors.black),
          ),
          title: const Text(
            'Employee Agreement',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => _editing = !_editing),
              child: Text(
                _editing ? 'Cancel' : 'Edit',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              employeeName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(_employeeTypeCtrl, 'Employee Type'),
                  const SizedBox(height: 8),
                  _field(
                    _basicSalaryCtrl,
                    'Basic Salary',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    _commissionCtrl,
                    'Commission (%)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _field(_descriptionCtrl, 'Description', maxLines: 4),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_editing)
              SizedBox(
                height: 46,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text(
                    'Save Agreement',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _editing,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) return 'Required';
        return null;
      },
    );
  }

  void _save() {
    if (widget.employee == null) {
      Navigator.of(context).pop();
      return;
    }
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    final updated = widget.employee!.copyWith(
      employeeType: _employeeTypeCtrl.text.trim(),
      basicSalary: _basicSalaryCtrl.text.trim(),
      commission: _commissionCtrl.text.trim(),
      agreementDescription: _descriptionCtrl.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }
}
