import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/widgets/assign_employees_sheet.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({super.key, required this.item});

  final EmployeeItem item;

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
  List<String> _assignedToIds = const <String>[];
  bool _editing = false;
  late bool _isActive;
  bool _usingOther = false;

  @override
  void initState() {
    super.initState();
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
    _assignedToIds = List<String>.from(item.assignedToIds);
    _isActive = item.isActive;

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
    _assignedToIds = List<String>.from(item.assignedToIds);
    _isActive = item.isActive;

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

  String _assignedToDisplay(EmployeesStore store) {
    if (_assignedToIds.isEmpty) return 'Unassigned';
    final names = _assignedToIds
        .map(store.byId)
        .whereType<EmployeeItem>()
        .map((e) => e.fullName)
        .toList(growable: false);
    return names.isEmpty ? 'Unassigned' : names.join(', ');
  }

  Future<void> _pickAssignedTo(EmployeesStore store) async {
    final result = await showAssignEmployeesSheet(
      context: context,
      employeeName: widget.item.fullName,
      others: store.assignTargets(excludeId: widget.item.id),
      selectedIds: _assignedToIds,
      assignedCount: (id) => store.peopleAssignedTo(id).length,
      isBlocked: (id) => store.wouldCreateCycle(widget.item.id, id),
    );
    if (result == null || !mounted) return;
    setState(() => _assignedToIds = result);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmployeesStore>();
    final categories = store.specialistCategories;
    final incomingCount = store.peopleAssignedTo(widget.item.id).length;

    return AdaptivePage(
      form: true,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          surfaceTintColor: const Color(0x00000000),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
          ),
          title: const Text(
            'Employee Details',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
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
                inputFormatters: [_PhonePkFormatter()],
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
              const SizedBox(height: 12),
              _labeledDropdown(
                label: 'Assigned to',
                child: InkWell(
                  onTap: () => _pickAssignedTo(store),
                  borderRadius: BorderRadius.circular(9),
                  child: InputDecorator(
                    decoration: _inputDecoration(),
                    child: Text(
                      _assignedToDisplay(store),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
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
              _viewRow('Assigned to', _assignedToDisplay(store)),
              _viewRow(
                'Assigned people',
                incomingCount == 0
                    ? 'None'
                    : '$incomingCount',
              ),
              _viewRow(
                'Status',
                _isActive ? 'Active' : 'Inactive',
                isLast: true,
              ),
            ],
          ],
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
    final phone = _phoneCtrl.text.trim();
    final cnic = _cnicCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final speciality = _specialityCtrl.text.trim();

    if (first.isEmpty ||
        last.isEmpty ||
        address.isEmpty ||
        !_isValidPkPhone(phone) ||
        !_isValidCnic(cnic)) {
      ToastService.error('Please fill valid details');
      return;
    }

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

    final updated = widget.item.copyWith(
      firstName: first,
      lastName: last,
      phoneNumber: phone,
      cnicNumber: cnic,
      homeAddress: address,
      speciality: speciality,
      employeeType: category,
      isActive: _isActive,
      photoBase64: _photoBase64,
      clearPhoto: _photoBase64 == null,
      assignedToIds: _assignedToIds,
    );
    ToastService.success('Employee updated');
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  bool _isValidPkPhone(String value) => RegExp(r'^\+92\d{10}$').hasMatch(value);

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
