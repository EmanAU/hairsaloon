import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_agreement_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_history_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

enum StaffListMode { employees, managers }

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({
    super.key,
    this.initialMode = StaffListMode.employees,
  });

  final StaffListMode initialMode;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showAddForm = false;
  String _statusTab = 'All';
  late StaffListMode _mode;
  String? _photoBase64;
  String? _specialistCategory;
  String? _selectedManagerId;
  bool _newActive = true;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+92');
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  final _otherCategoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _addressCtrl.dispose();
    _specialityCtrl.dispose();
    _otherCategoryCtrl.dispose();
    super.dispose();
  }

  List<EmployeeItem> _baseList(EmployeesStore store) =>
      _mode == StaffListMode.managers ? store.managers : store.employees;

  List<EmployeeItem> _filtered(EmployeesStore store) {
    final list = _baseList(store);
    if (_statusTab == 'All') return list;
    if (_statusTab == 'Active') {
      return list.where((e) => e.isActive).toList(growable: false);
    }
    return list.where((e) => !e.isActive).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmployeesStore>();
    final items = _filtered(store);
    final isManagers = _mode == StaffListMode.managers;
    final title = isManagers
        ? 'Managers (${store.managers.length.toString().padLeft(2, '0')})'
        : 'Employees (${store.employees.length.toString().padLeft(2, '0')})';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              CupertinoIcons.ellipsis_vertical,
              color: AppColors.onPrimary,
            ),
            onSelected: (value) {
              if (value == 'employees') {
                setState(() {
                  _mode = StaffListMode.employees;
                  _showAddForm = false;
                  _resetFormFields();
                });
              } else if (value == 'managers') {
                setState(() {
                  _mode = StaffListMode.managers;
                  _showAddForm = false;
                  _resetFormFields();
                });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'employees', child: Text('Employees')),
              PopupMenuItem(value: 'managers', child: Text('Managers')),
            ],
          ),
          IconButton(
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
            icon: Icon(
              _showAddForm ? CupertinoIcons.xmark : CupertinoIcons.add,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: SafeScrollPadding.of(
          context,
          left: 12,
          top: 12,
          right: 12,
          bottom: 24,
        ),
        children: [
          _buildStatusTabs(),
          const SizedBox(height: 10),
          if (_showAddForm) ...[
            _addForm(store),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  isManagers ? 'No managers yet.' : 'No employees yet.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ...items.map((e) => _staffCard(store, e)),
        ],
      ),
    );
  }

  Widget _staffCard(EmployeesStore store, EmployeeItem e) {
    final manager = store.managerOf(e.managerId);
    final teamCount = e.isManager ? store.employeesForManager(e.id).length : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final bills = context
            .read<BillingStore>()
            .bills
            .where((b) => b.employeeName == e.fullName)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmployeeHistoryScreen(employee: e, bills: bills),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
        child: Row(
          children: [
            _StaffAvatar(photoBase64: e.photoBase64, name: e.fullName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.speciality?.trim().isNotEmpty == true
                        ? e.speciality!
                        : (e.isManager ? 'Manager' : 'General Specialist'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    e.fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if ((e.employeeType ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _chip(e.employeeType!.trim()),
                  ],
                  if (!e.isManager && manager != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Manager: ${manager.fullName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (e.isManager) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$teamCount employee${teamCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              e.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: e.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _onMenuAction(store, e, value),
              itemBuilder: (_) => [
                if (!e.isManager)
                  const PopupMenuItem(
                    value: 'assign',
                    child: Text('Assign Manager'),
                  ),
                if (!e.isManager)
                  const PopupMenuItem(
                    value: 'agreement',
                    child: Text('Agreement'),
                  ),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }

  Future<void> _onMenuAction(
    EmployeesStore store,
    EmployeeItem e,
    String value,
  ) async {
    if (value == 'assign') {
      await _showAssignManagerSheet(store, e);
      return;
    }
    if (value == 'agreement') {
      final updated = await Navigator.of(context).push<EmployeeItem>(
        MaterialPageRoute(
          builder: (_) => EmployeeAgreementScreen(employee: e),
        ),
      );
      if (updated == null) return;
      await store.update(updated);
      return;
    }
    if (value == 'edit') {
      final updated = await Navigator.of(context).push<EmployeeItem>(
        MaterialPageRoute(builder: (_) => EmployeeDetailsScreen(item: e)),
      );
      if (updated == null) return;
      await store.update(updated);
      return;
    }
    if (value == 'delete') {
      final confirm = await showAppConfirmDialog(
        context: context,
        title: e.isManager ? 'Delete Manager' : 'Delete Employee',
        message: e.isManager
            ? 'Delete ${e.fullName}? Assigned employees will be unassigned.'
            : 'Delete ${e.fullName}?',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        isDestructive: true,
      );
      if (confirm != true) return;
      await store.delete(e.id);
      ToastService.success(e.isManager ? 'Manager deleted' : 'Employee deleted');
    }
  }

  Future<void> _showAssignManagerSheet(
    EmployeesStore store,
    EmployeeItem employee,
  ) async {
    final managers = store.managers;
    const unassigned = '';
    final selected = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => AppSheetBody(
        title: 'Assign Manager',
        subtitle: employee.fullName,
        icon: CupertinoIcons.person_2,
        showCancel: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetOption(
              label: 'Unassigned',
              icon: CupertinoIcons.person_crop_circle_badge_xmark,
              selected: employee.managerId == null,
              onTap: () => Navigator.pop(sheetContext, unassigned),
            ),
            if (managers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No managers yet. Add a manager first.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            for (final manager in managers)
              AppSheetOption(
                label: manager.fullName,
                subtitle:
                    '${store.employeesForManager(manager.id).length} employees',
                icon: CupertinoIcons.person_crop_circle,
                selected: employee.managerId == manager.id,
                onTap: () => Navigator.pop(sheetContext, manager.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    final managerId = selected == unassigned ? null : selected;
    if (managerId == employee.managerId) return;
    await store.assignEmployeeToManager(
      employeeId: employee.id,
      managerId: managerId,
    );
    if (managerId == null) {
      ToastService.success('Manager unassigned');
      return;
    }
    final manager = managers.firstWhere((m) => m.id == managerId);
    ToastService.success('Assigned to ${manager.fullName}');
  }

  Widget _addForm(EmployeesStore store) {
    final isManager = _mode == StaffListMode.managers;
    final categories = store.specialistCategories;
    final showOther = _specialistCategory == 'Other';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isManager ? 'Add Manager' : 'Add Employee',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            BusinessLogoPicker(
              value: _photoBase64,
              title: 'Photo',
              emptyHint: 'Optional · camera or gallery',
              filledHint: 'Tap to change or remove',
              onChanged: (value) => setState(() => _photoBase64 = value),
            ),
            const SizedBox(height: 12),
            _field(_firstNameCtrl, 'First Name'),
            const SizedBox(height: 8),
            _field(_lastNameCtrl, 'Last Name'),
            const SizedBox(height: 8),
            _field(
              _phoneCtrl,
              'Phone Number',
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhonePkFormatter()],
            ),
            const SizedBox(height: 8),
            _field(
              _cnicCtrl,
              'CNIC Number',
              keyboardType: TextInputType.number,
              inputFormatters: [_CnicFormatter()],
            ),
            const SizedBox(height: 8),
            _field(_addressCtrl, 'Home Address'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _specialistCategory,
              isExpanded: true,
              decoration: _dropdownDecoration('Specialist Category'),
              items: categories
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _specialistCategory = value;
                if (value != 'Other') {
                  _otherCategoryCtrl.clear();
                }
              }),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            if (showOther) ...[
              const SizedBox(height: 8),
              _field(
                _otherCategoryCtrl,
                'Other category name',
              ),
            ],
            const SizedBox(height: 8),
            _field(_specialityCtrl, 'Speciality'),
            if (!isManager) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedManagerId ?? '',
                isExpanded: true,
                decoration: _dropdownDecoration('Assign Manager (optional)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text(
                      'Unassigned',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  ...store.managers.map(
                    (manager) => DropdownMenuItem(
                      value: manager.id,
                      child: Text(
                        manager.fullName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _selectedManagerId =
                      (value == null || value.isEmpty) ? null : value,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1E1E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _newActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _newActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    activeThumbColor: AppColors.onPrimary,
                    value: _newActive,
                    onChanged: (value) => setState(() => _newActive = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _save(store),
                child: Text(
                  isManager ? 'Save Manager' : 'Save Employee',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
        ),
      ),
      validator: (v) {
        final value = (v ?? '').trim();
        if (value.isEmpty) return 'Required';
        if (hint == 'Phone Number' && !_isValidPkPhone(value)) {
          return 'Use +92 followed by 10 digits';
        }
        if (hint == 'CNIC Number' && !_isValidCnic(value)) {
          return 'Use format: 12345-1234567-1';
        }
        return null;
      },
    );
  }

  Future<void> _save(EmployeesStore store) async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    var category = _specialistCategory?.trim();
    if (category == 'Other') {
      final other = _otherCategoryCtrl.text.trim();
      if (other.isEmpty) {
        ToastService.error('Enter the other category name');
        return;
      }
      category = other;
      await store.addSpecialistCategory(other);
    }

    final isManager = _mode == StaffListMode.managers;
    await store.add(
      EmployeeItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        cnicNumber: _cnicCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        isActive: _newActive,
        role: isManager ? EmployeeRole.manager : EmployeeRole.employee,
        managerId: isManager ? null : _selectedManagerId,
        photoBase64: _photoBase64,
        speciality: _specialityCtrl.text.trim(),
        employeeType: category,
      ),
    );

    setState(() {
      _showAddForm = false;
      _resetFormFields();
    });
    ToastService.success(isManager ? 'Manager saved' : 'Employee saved');
  }

  void _resetFormFields() {
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _phoneCtrl.text = '+92';
    _cnicCtrl.clear();
    _addressCtrl.clear();
    _specialityCtrl.clear();
    _otherCategoryCtrl.clear();
    _specialistCategory = null;
    _selectedManagerId = null;
    _photoBase64 = null;
    _newActive = true;
  }

  Widget _buildStatusTabs() {
    const tabs = ['All', 'Active', 'Inactive'];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final selected = tab == _statusTab;
          return ChoiceChip(
            label: Text(tab),
            selected: selected,
            selectedColor: AppColors.surface,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : const Color(0xFFE1E1E1),
            ),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            onSelected: (_) => setState(() => _statusTab = tab),
          );
        },
      ),
    );
  }

  bool _isValidPkPhone(String value) => RegExp(r'^\+92\d{10}$').hasMatch(value);

  bool _isValidCnic(String value) =>
      RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(value);
}

class _StaffAvatar extends StatelessWidget {
  const _StaffAvatar({required this.photoBase64, required this.name});

  final String? photoBase64;
  final String name;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (photoBase64 != null && photoBase64!.isNotEmpty) {
        bytes = base64Decode(photoBase64!);
      }
    } on FormatException {
      bytes = null;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
    );
  }
}

class _CnicFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PhonePkFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final onlyDigits = text.replaceAll(RegExp(r'[^0-9]'), '');

    String afterPrefixDigits;
    if (text.startsWith('+92')) {
      afterPrefixDigits = text.substring(3).replaceAll(RegExp(r'[^0-9]'), '');
    } else if (onlyDigits.startsWith('92')) {
      afterPrefixDigits = onlyDigits.substring(2);
    } else {
      afterPrefixDigits = onlyDigits;
    }

    if (afterPrefixDigits.length > 10) {
      afterPrefixDigits = afterPrefixDigits.substring(0, 10);
    }

    final formatted = '+92$afterPrefixDigits';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
