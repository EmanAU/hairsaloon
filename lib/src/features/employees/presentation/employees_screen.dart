import 'package:hairsaloon/src/core/utils/pk_cnic.dart';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_agreement_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_history_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/online/presentation/employee_invite_flows.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'employee_photo.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../online/domain/online_models.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showAddForm = false;
  String _statusTab = 'All';
  String? _photoBase64;
  String? _specialistCategory;
  bool _newActive = true;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: PkPhone.inputPrefix);
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  final _otherCategoryCtrl = TextEditingController();

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

  List<EmployeeItem> _filtered(EmployeesStore store) {
    final list = store.employees;
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
    final title =
        'Employees (${store.employees.length.toString().padLeft(2, '0')})';

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
          IconButton(
            onPressed: () async {
              final online = context.read<BusinessWorkspace?>();
              if (online != null) {
                await showEmployeeInviteOptions(context);
                return;
              }
              setState(() => _showAddForm = !_showAddForm);
            },
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
          if (_showAddForm) ...[_addForm(store), const SizedBox(height: 12)],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No employees yet.',
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final bills =
            context
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
            if (e.onlineSynced)
              EmployeePhoto(employee: e)
            else
              _StaffAvatar(photoBase64: e.photoBase64, name: e.fullName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.speciality?.trim().isNotEmpty == true
                        ? e.speciality!
                        : 'General Specialist',
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
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (e.isManager) _chip('Manager'),
                      if ((e.employeeType ?? '').trim().isNotEmpty)
                        _chip(e.employeeType!.trim()),
                    ],
                  ),
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
                PopupMenuItem(
                  value: e.isManager ? 'remove_manager' : 'make_manager',
                  child: Text(
                    e.isManager ? 'Remove as manager' : 'Make manager',
                  ),
                ),
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
    if (value == 'make_manager') {
      final current = store.manager;
      final message = current == null || current.id == e.id
          ? 'Make ${e.fullName} the shop manager? They can still work as an employee.'
          : '${current.fullName} is the current manager. Replace them with ${e.fullName}?';
      final confirm = await showAppConfirmDialog(
        context: context,
        title: 'Make manager?',
        message: message,
        cancelLabel: 'Cancel',
        confirmLabel: 'Make manager',
      );
      if (confirm != true) return;
      if (!mounted) return;
      final workspace = context.read<BusinessWorkspace?>();
      if (workspace != null && e.onlineSynced) {
        final pin = await showAppTextInputSheet(
          context: context,
          title: 'Manager PIN',
          label: '4-digit PIN',
          subtitle: 'Share this PIN with ${e.fullName}.',
          keyboardType: TextInputType.number,
          maxLength: 4,
          validator: (value) => RegExp(r'^\d{4}$').hasMatch(value)
              ? null
              : 'Enter exactly 4 digits',
        );
        if (pin == null || !mounted) return;
        try {
          await workspace.repository.setEmployeeManager(
            employeeId: e.id,
            isManager: true,
            pin: pin,
          );
        } catch (error) {
          if (mounted) {
            ToastService.error(
              error is OnlineFailure
                  ? error.message
                  : 'Could not grant manager access. Please retry.',
              context,
            );
          }
          return;
        }
      }
      await store.setManager(e.id);
      ToastService.success('${e.fullName} is now manager');
      return;
    }
    if (value == 'remove_manager') {
      final confirm = await showAppConfirmDialog(
        context: context,
        title: 'Remove manager?',
        message:
            'Remove manager role from ${e.fullName}? They remain an employee.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Remove',
      );
      if (confirm != true) return;
      if (!mounted) return;
      final workspace = context.read<BusinessWorkspace?>();
      if (workspace != null && e.onlineSynced) {
        try {
          await workspace.repository.setEmployeeManager(
            employeeId: e.id,
            isManager: false,
          );
        } catch (error) {
          if (mounted) {
            ToastService.error(
              error is OnlineFailure
                  ? error.message
                  : 'Could not remove manager access. Please retry.',
              context,
            );
          }
          return;
        }
      }
      await store.removeManager(e.id);
      ToastService.success('Manager role removed');
      return;
    }
    if (value == 'agreement') {
      final updated = await Navigator.of(context).push<EmployeeItem>(
        MaterialPageRoute(builder: (_) => EmployeeAgreementScreen(employee: e)),
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
        title: 'Delete Employee',
        message: e.isManager
            ? 'Delete ${e.fullName}? They are currently the manager.'
            : 'Delete ${e.fullName}?',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        isDestructive: true,
      );
      if (confirm != true) return;
      await store.delete(e.id);
      ToastService.success('Employee deleted');
    }
  }

  Widget _addForm(EmployeesStore store) {
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
                'Add Employee',
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
              inputFormatters: [PkPhoneInputFormatter()],
            ),
            const SizedBox(height: 8),
            _field(
              _cnicCtrl,
              'CNIC Number',
              keyboardType: TextInputType.number,
              inputFormatters: [PkCnicInputFormatter()],
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
              _field(_otherCategoryCtrl, 'Other category name'),
            ],
            const SizedBox(height: 8),
            _field(_specialityCtrl, 'Speciality'),
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
                child: const Text(
                  'Save Employee',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        if (hint == 'Phone Number') {
          return PkPhone.validationError(value);
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

    final employee = EmployeeItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      phoneNumber: PkPhone.normalize(_phoneCtrl.text),
      cnicNumber: _cnicCtrl.text.trim(),
      homeAddress: _addressCtrl.text.trim(),
      isActive: _newActive,
      photoBase64: _photoBase64,
      speciality: _specialityCtrl.text.trim(),
      employeeType: category,
    );
    await store.add(employee);

    setState(() {
      _showAddForm = false;
      _resetFormFields();
    });
    ToastService.success('Employee saved');

    if (!mounted) return;
    final saved = store.byId(employee.id) ?? employee;
    final updated = await Navigator.of(context).push<EmployeeItem>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeAgreementScreen(employee: saved, requireCompletion: true),
      ),
    );
    if (updated == null || !mounted) return;
    await store.update(updated);
  }

  void _resetFormFields() {
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _phoneCtrl.text = PkPhone.inputPrefix;
    _cnicCtrl.clear();
    _addressCtrl.clear();
    _specialityCtrl.clear();
    _otherCategoryCtrl.clear();
    _specialistCategory = null;
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

  bool _isValidCnic(String value) => PkCnic.isValid(value);
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
