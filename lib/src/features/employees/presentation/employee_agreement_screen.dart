import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class EmployeeAgreementScreen extends StatefulWidget {
  const EmployeeAgreementScreen({
    super.key,
    this.employee,
    this.requireCompletion = false,
  });

  final EmployeeItem? employee;

  /// When true, user must save a complete agreement before leaving.
  final bool requireCompletion;

  @override
  State<EmployeeAgreementScreen> createState() =>
      _EmployeeAgreementScreenState();
}

class _EmployeeAgreementScreenState extends State<EmployeeAgreementScreen> {
  static const Color _divider = Color(0xFFE1E1E1);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeTypeCtrl;
  late final TextEditingController _basicSalaryCtrl;
  late final TextEditingController _commissionCtrl;
  late final TextEditingController _descriptionCtrl;
  late bool _editing;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _editing = widget.requireCompletion;
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

  void _cancelEdit() {
    setState(() {
      _employeeTypeCtrl.text = widget.employee?.employeeType ?? '';
      _basicSalaryCtrl.text = widget.employee?.basicSalary ?? '';
      _commissionCtrl.text = widget.employee?.commission ?? '';
      _descriptionCtrl.text = widget.employee?.agreementDescription ?? '';
      _editing = false;
    });
  }

  void _onBack() {
    if (widget.requireCompletion && !_completed) {
      ToastService.error('Complete the employee agreement to continue');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = widget.employee?.fullName ?? 'Employee';
    final mustComplete = widget.requireCompletion && !_completed;

    return PopScope(
      canPop: !mustComplete,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: AdaptivePage(
        form: true,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            surfaceTintColor: const Color(0x00000000),
            leading: IconButton(
              onPressed: _onBack,
              icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
            ),
            title: const Text(
              'Employee Agreement',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (!widget.requireCompletion)
                TextButton(
                  onPressed: () {
                    if (_editing) {
                      _cancelEdit();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
                  child: Text(
                    _editing ? 'Cancel' : 'Edit',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: SafeScrollPadding.of(
              context,
              left: 20,
              top: 18,
              right: 20,
              bottom: 32,
            ),
            children: [
              Text(
                employeeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.requireCompletion
                    ? 'Required: set salary, commission and agreement terms'
                    : 'Salary, commission and agreement terms',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              if (_editing)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _editField(
                        _employeeTypeCtrl,
                        'Employee type',
                        helper:
                            'Role or contract type (e.g. Full-time, Stylist)',
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        _basicSalaryCtrl,
                        'Basic salary',
                        helper: 'Monthly fixed salary amount',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        _commissionCtrl,
                        'Commission (%)',
                        helper: 'Percentage earned on sales',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        _descriptionCtrl,
                        'Agreement description',
                        helper: 'Notes about terms, payout rules, etc.',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          onPressed: _save,
                          child: const Text(
                            'Save Agreement',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _viewRow(
                      'Employee type',
                      _employeeTypeCtrl.text,
                      hint: 'Role or contract type',
                    ),
                    _viewRow(
                      'Basic salary',
                      _basicSalaryCtrl.text.isEmpty
                          ? ''
                          : 'Rs. ${_basicSalaryCtrl.text}',
                      hint: 'Monthly fixed salary',
                    ),
                    _viewRow(
                      'Commission',
                      _commissionCtrl.text.isEmpty
                          ? ''
                          : '${_commissionCtrl.text}%',
                      hint: 'Percent on sales',
                    ),
                    _viewRow(
                      'Agreement description',
                      _descriptionCtrl.text,
                      hint: 'Terms and notes',
                      isLast: true,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewRow(
    String label,
    String value, {
    required String hint,
    bool isLast = false,
  }) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.75),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            display,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    required String helper,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    const radius = BorderRadius.all(Radius.circular(9));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          helper,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.danger, width: 1.5),
            ),
            errorStyle: TextStyle(fontSize: 11),
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Required';
            return null;
          },
        ),
      ],
    );
  }

  void _save() {
    if (widget.employee == null) {
      Navigator.of(context).pop();
      return;
    }
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    final commissionText = _commissionCtrl.text.trim();
    final commission = double.tryParse(
      commissionText.replaceAll(',', '').replaceAll('%', ''),
    );
    if (commission == null || commission <= 0) {
      ToastService.error('Enter a commission greater than 0');
      return;
    }

    final updated = widget.employee!.copyWith(
      employeeType: _employeeTypeCtrl.text.trim(),
      basicSalary: _basicSalaryCtrl.text.trim(),
      commission: commissionText,
      agreementDescription: _descriptionCtrl.text.trim(),
    );
    _completed = true;
    ToastService.success('Agreement saved');
    Navigator.of(context).pop(updated);
  }
}
