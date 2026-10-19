import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({
    super.key,
    required this.item,
    this.requireCompletion = false,
  });

  final EmployeeItem item;

  /// After online invite + contract: stay in edit until profile fields are filled.
  final bool requireCompletion;

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  static const Color _divider = Color(0xFFE1E1E1);

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cnicCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _specialityCtrl;
  late final TextEditingController _otherCategoryCtrl;
  String? _specialistCategory;
  String? _photoBase64;
  late bool _editing;
  late bool _isActive;
  late bool _isManager;
  bool _usingOther = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _editing = widget.requireCompletion;
    _hydrateFrom(widget.item);
  }

  void _hydrateFrom(EmployeeItem item) {
    _firstNameCtrl = TextEditingController(text: item.firstName);
    _lastNameCtrl = TextEditingController(text: item.lastName);
    _phoneCtrl = TextEditingController(text: item.phoneNumber);
    _cnicCtrl = TextEditingController(text: item.cnicNumber);
    _addressCtrl = TextEditingController(text: item.homeAddress);
    _specialityCtrl = TextEditingController(text: item.speciality ?? '');
    _otherCategoryCtrl = TextEditingController();
    _photoBase64 = item.photoBase64;
    _isActive = item.isActive;
    _isManager = item.isManager;

    final type = (item.employeeType ?? '').trim();
    final defaults = EmployeesStore.defaultSpecialistCategories
        .where((c) => c != 'Other')
        .toSet();
    if (type.isEmpty) {
      _specialistCategory = null;
      _usingOther = false;
    } else if (defaults.contains(type) || type == 'Other') {
      _specialistCategory = type;
      _usingOther = type == 'Other';
    } else {
      _specialistCategory = 'Other';
      _usingOther = true;
      _otherCategoryCtrl.text = type;
    }
  }

  void _resetFromItem() {
    final item = widget.item;
    _firstNameCtrl.text = item.firstName;
    _lastNameCtrl.text = item.lastName;
    _phoneCtrl.text = item.phoneNumber;
    _cnicCtrl.text = item.cnicNumber;
    _addressCtrl.text = item.homeAddress;
    _specialityCtrl.text = item.speciality ?? '';
    _photoBase64 = item.photoBase64;
    _isActive = item.isActive;
    _isManager = item.isManager;

    final type = (item.employeeType ?? '').trim();
    final defaults = EmployeesStore.defaultSpecialistCategories
        .where((c) => c != 'Other')
        .toSet();
    if (type.isEmpty) {
      _specialistCategory = null;
      _usingOther = false;
      _otherCategoryCtrl.clear();
    } else if (defaults.contains(type) || type == 'Other') {
      _specialistCategory = type;
      _usingOther = type == 'Other';
      if (!_usingOther) _otherCategoryCtrl.clear();
    } else {
      _specialistCategory = 'Other';
      _usingOther = true;
      _otherCategoryCtrl.text = type;
    }
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

  String get _resolvedCategory {
    if (_specialistCategory == 'Other') {
      final other = _otherCategoryCtrl.text.trim();
      return other.isEmpty ? 'Other' : other;
    }
    return (_specialistCategory ?? '').trim();
  }

  void _onBack() {
    if (widget.requireCompletion && !_completed) {
      ToastService.error('Complete the employee profile to continue');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmployeesStore>();
    final categories = store.specialistCategories;
    final otherManager = store.manager;
    final replacingManager = _isManager &&
        otherManager != null &&
        otherManager.id != widget.item.id;

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
            title: Text(
              mustComplete ? 'Complete employee profile' : 'Employee Details',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (!mustComplete)
                TextButton(
                  onPressed: () => setState(() {
                    if (_editing) {
                      _resetFromItem();
                      _editing = false;
                    } else {
                      _editing = true;
                    }
                  }),
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
            BusinessLogoPicker(
              value: _photoBase64,
              enabled: _editing,
              title: 'Photo',
              emptyHint: 'Optional · camera or gallery',
              filledHint: 'Tap to change or remove',
              onChanged: (value) => setState(() => _photoBase64 = value),
            ),
            const SizedBox(height: 18),
            if (_editing) ...[
              _editField(_firstNameCtrl, 'First name'),
              const SizedBox(height: 12),
              _editField(_lastNameCtrl, 'Last name'),
              const SizedBox(height: 12),
              _editField(
                _phoneCtrl,
                'Phone number',
                keyboardType: TextInputType.phone,
                inputFormatters: [PkPhoneInputFormatter()],
              ),
              const SizedBox(height: 12),
              _editField(
                _cnicCtrl,
                'CNIC number',
                keyboardType: TextInputType.number,
                inputFormatters: [_CnicFormatter()],
              ),
              const SizedBox(height: 12),
              _editField(_addressCtrl, 'Home address'),
              const SizedBox(height: 12),
              _labeledDropdown(
                label: 'Specialist category',
                child: DropdownButtonFormField<String>(
                  initialValue: _specialistCategory,
                  isExpanded: true,
                  decoration: _inputDecoration(),
                  items: <String>{
                    ...categories,
                    if (_specialistCategory != null) _specialistCategory!,
                  }.map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ).toList(growable: false),
                  onChanged: (v) => setState(() {
                    _specialistCategory = v;
                    _usingOther = v == 'Other';
                    if (!_usingOther) _otherCategoryCtrl.clear();
                  }),
                ),
              ),
              if (_usingOther || _specialistCategory == 'Other') ...[
                const SizedBox(height: 12),
                _editField(_otherCategoryCtrl, 'Other category name'),
              ],
              const SizedBox(height: 12),
              _editField(_specialityCtrl, 'Speciality'),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Shop manager',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  replacingManager
                      ? 'Will replace ${otherManager.fullName} as the only manager'
                      : 'Only one manager allowed; they can still work',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _isManager,
                onChanged: (value) => setState(() => _isManager = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Employee active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () => _save(store),
                  child: Text(
                    mustComplete ? 'Save profile' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ] else ...[
              _viewRow('First name', _firstNameCtrl.text),
              _viewRow('Last name', _lastNameCtrl.text),
              _viewRow('Phone number', _phoneCtrl.text),
              _viewRow('CNIC number', _cnicCtrl.text),
              _viewRow('Home address', _addressCtrl.text),
              _viewRow('Specialist category', _resolvedCategory),
              _viewRow('Speciality', _specialityCtrl.text),
              _viewRow('Role', _isManager ? 'Manager' : 'Employee'),
              _viewRow(
                'Status',
                _isActive ? 'Active' : 'Inactive',
                isLast: true,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _viewRow(String label, String value, {bool isLast = false}) {
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
          const SizedBox(height: 4),
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

  Widget _labeledDropdown({required String label, required Widget child}) {
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
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration() {
    const radius = BorderRadius.all(Radius.circular(9));
    return const InputDecoration(
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
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _divider),
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Future<void> _save(EmployeesStore store) async {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final phone = PkPhone.normalize(_phoneCtrl.text);
    final cnic = _cnicCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final speciality = _specialityCtrl.text.trim();

    if (first.isEmpty ||
        last.isEmpty ||
        address.isEmpty ||
        !PkPhone.isValid(phone) ||
        !_isValidCnic(cnic)) {
      ToastService.error(
        'Fill name, 11-digit phone (03…), CNIC, and home address.',
      );
      return;
    }

    var category = _specialistCategory?.trim();
    if (category == null || category.isEmpty) {
      ToastService.error('Select a specialist category');
      return;
    }
    if (category == 'Other') {
      final other = _otherCategoryCtrl.text.trim();
      if (other.isEmpty) {
        ToastService.error('Enter the other category name');
        return;
      }
      category = other;
      await store.addSpecialistCategory(other);
    }

    final updated = widget.item.copyWith(
      firstName: first,
      lastName: last,
      phoneNumber: phone,
      cnicNumber: cnic,
      homeAddress: address,
      speciality: speciality,
      employeeType: category,
      isActive: _isActive,
      isManager: _isManager,
      photoBase64: _photoBase64,
      clearPhoto: _photoBase64 == null,
    );
    await store.update(updated);
    _completed = true;
    ToastService.success(
      widget.requireCompletion
          ? 'Employee profile complete'
          : 'Employee updated',
    );
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  bool _isValidCnic(String value) =>
      RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(value);
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
