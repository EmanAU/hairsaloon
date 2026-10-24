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
import 'package:uuid/uuid.dart';
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
  bool _savingNew = false;
  DateTime? _dateOfBirth, _workStartedOn;
  final _emailCtrl = TextEditingController();

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
    _emailCtrl.dispose();
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              setState(() => _showAddForm = !_showAddForm);
            },
            icon: Icon(
              _showAddForm ? CupertinoIcons.xmark : CupertinoIcons.add,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: SafeScrollPadding.of(
              context,
              left: 20,
              top: 20,
              right: 20,
              bottom: 24,
            ),
            children: [
              _buildStatusTabs(),
              const SizedBox(height: 10),
              if (!_showAddForm)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAddForm = true),
                  icon: const Icon(CupertinoIcons.person_add, size: 19),
                  style: _entryButtonStyle(
                    const Color(0xFFF1F8DA),
                    const Color(0xFFCFDDB0),
                  ),
                  label: const Text('Create employee'),
                ),
              if (context.read<BusinessWorkspace?>() != null)
                OutlinedButton.icon(
                  onPressed: () => showEmployeeInviteOptions(context),
                  icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 19),
                  style: _entryButtonStyle(
                    const Color(0xFFF1F4FC),
                    const Color(0xFFD4DCED),
                  ),
                  label: const Text(
                    'Invite an existing profile or scan QR',
                    textAlign: TextAlign.center,
                  ),
                ),
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
        ),
      ),
    );
  }

  ButtonStyle _entryButtonStyle(Color fill, Color border) =>
      OutlinedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: AppColors.homeInk,
        side: BorderSide(color: border),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.homeInk,
        ),
      ),
    ),
  );

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
      padding: const EdgeInsets.all(16),
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
                'Create employee',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            BusinessLogoPicker(
              value: _photoBase64,
              title: 'Add employee photo',
              placeholderIcon: CupertinoIcons.person_crop_circle,
              emptyHint: 'Optional · camera or gallery',
              filledHint: 'Tap to change or remove',
              onChanged: (value) => setState(() => _photoBase64 = value),
            ),
            _section('Personal details'),
            _field(_firstNameCtrl, 'First Name'),
            const SizedBox(height: 8),
            _field(_lastNameCtrl, 'Last Name'),
            if (context.read<BusinessWorkspace?>() != null) ...[
              const SizedBox(height: 8),
              _field(
                _emailCtrl,
                'Google Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Use the email they will select with Continue with Google.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dateField(
              'Date of birth',
              _dateOfBirth,
              (date) => _dateOfBirth = date,
            ),
            const SizedBox(height: 8),
            _dateField(
              'Work started on',
              _workStartedOn,
              (date) => _workStartedOn = date,
            ),
            if (_workStartedOn != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Experience: ${PersonalProfile(code: '', phone: '', workStartedOn: _workStartedOn).experienceAt(DateTime.now())}',
                ),
              ),
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
            _section('Work & speciality'),
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
                onPressed: _savingNew ? null : () => _save(store),
                child: Text(
                  _savingNew ? 'Saving…' : 'Save Employee',
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
      labelText: hint,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: const Color(0xFFFAFBF8),
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
        labelText: hint,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: const Color(0xFFFAFBF8),
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
        if (hint == 'Last Name') return null;
        if (value.isEmpty) return 'Required';
        if (hint == 'Google Email' &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
          return 'Enter their Google email';
        }
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
    if (_savingNew) return;
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;
    final workspace = context.read<BusinessWorkspace?>();
    if (workspace != null &&
        (_dateOfBirth == null ||
            _workStartedOn == null ||
            _workStartedOn!.isBefore(_dateOfBirth!))) {
      ToastService.error(
        'Select a valid birth date and work start date.',
        context,
      );
      return;
    }
    if (store.employees.any(
      (e) => PkCnic.digits(e.cnicNumber) == PkCnic.digits(_cnicCtrl.text),
    )) {
      ToastService.error(
        'This employee already exists. Open their details to edit.',
        context,
      );
      return;
    }
    setState(() => _savingNew = true);
    try {
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
        id: const Uuid().v4(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: PkPhone.normalize(_phoneCtrl.text),
        cnicNumber: _cnicCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        isActive: _newActive,
        photoBase64: _photoBase64,
        speciality: _specialityCtrl.text.trim(),
        employeeType: category,
        email: _emailCtrl.text.trim().toLowerCase(),
        dateOfBirth: _dateOfBirth,
        workStartedOn: _workStartedOn,
      );
      await store.add(employee);
      final synced = workspace == null || await workspace.syncEmployeeRecords();
      if (!mounted) return;

      setState(() {
        _showAddForm = false;
        _resetFormFields();
      });
      if (synced) {
        ToastService.success(
          workspace == null
              ? 'Employee saved'
              : 'Employee saved. They can accept your invitation with Google.',
          context,
        );
      } else {
        ToastService.info(
          'Employee saved on this device. Invitation will sync when connected.',
          context,
        );
      }
      if (workspace != null) {
        await workspace.synchronize();
        return;
      }

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
    } catch (_) {
      if (mounted) {
        ToastService.error(
          'Could not save this employee. Your details are still here.',
          context,
        );
      }
    } finally {
      if (mounted) setState(() => _savingNew = false);
    }
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> change,
  ) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBF8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        value == null
            ? 'Select date'
            : '${value.day}/${value.month}/${value.year}',
      ),
      trailing: const Icon(CupertinoIcons.calendar, size: 20),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              value ?? DateTime(label == 'Date of birth' ? 2000 : 2020),
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) setState(() => change(date));
      },
    ),
  );

  void _resetFormFields() {
    _emailCtrl.clear();
    _dateOfBirth = null;
    _workStartedOn = null;
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
