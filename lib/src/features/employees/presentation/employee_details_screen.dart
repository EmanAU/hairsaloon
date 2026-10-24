import 'package:hairsaloon/src/core/utils/pk_cnic.dart';
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
import '../../../online/domain/online_repository.dart';
import '../../../online/domain/online_models.dart';
import '../../../online/data/business_workspace.dart';
import 'employee_photo.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({
    super.key,
    required this.item,
    this.requireCompletion = false,
    this.repository,
  });

  final EmployeeItem item;

  /// After online invite + contract: stay in edit until profile fields are filled.
  final bool requireCompletion;
  final OnlineRepository? repository;

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
  bool _saving = false;
  String? _saveError;
  final _managerPin = TextEditingController();
  late final _email = TextEditingController(text: widget.item.email);
  DateTime? _birth, _started;

  @override
  void initState() {
    super.initState();
    _editing = widget.requireCompletion;
    _hydrateFrom(widget.item);
    _birth = widget.item.dateOfBirth;
    _started = widget.item.workStartedOn;
  }

  void _hydrateFrom(EmployeeItem item) {
    _firstNameCtrl = TextEditingController(text: item.firstName);
    _lastNameCtrl = TextEditingController(text: item.lastName);
    _phoneCtrl = TextEditingController(
      text: PkPhone.localNumber(item.phoneNumber),
    );
    _cnicCtrl = TextEditingController(text: _displayCnic(item.cnicNumber));
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
    _email.text = item.email;
    _birth = item.dateOfBirth;
    _started = item.workStartedOn;
    _firstNameCtrl.text = item.firstName;
    _lastNameCtrl.text = item.lastName;
    _phoneCtrl.text = PkPhone.localNumber(item.phoneNumber);
    _cnicCtrl.text = _displayCnic(item.cnicNumber);
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
    _managerPin.dispose();
    _email.dispose();
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
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmployeesStore>();
    final categories = store.specialistCategories;
    final otherManager = store.manager;
    final replacingManager =
        _isManager && otherManager != null && otherManager.id != widget.item.id;

    final mustComplete = widget.requireCompletion && !_completed;

    return PopScope(
      canPop: !_saving,
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
                  onPressed: _saving
                      ? null
                      : () => setState(() {
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
              if (widget.item.onlineSynced) ...[
                Center(
                  child: EmployeePhoto(
                    employee: widget.item,
                    repository: widget.repository,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Personal profile photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'This person manages their photo from their own profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ] else
                BusinessLogoPicker(
                  value: _photoBase64,
                  enabled: _editing && !_saving,
                  title: 'Photo',
                  emptyHint: 'Optional · camera or gallery',
                  filledHint: 'Tap to change or remove',
                  onChanged: (value) => setState(() => _photoBase64 = value),
                ),
              const SizedBox(height: 18),
              if (_editing) ...[
                _editField(_firstNameCtrl, 'First name'),
                const SizedBox(height: 12),
                _editField(
                  _lastNameCtrl,
                  widget.item.onlineSynced
                      ? 'Last name (optional)'
                      : 'Last name',
                ),
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
                  inputFormatters: [PkCnicInputFormatter()],
                ),
                const SizedBox(height: 12),
                _editField(_addressCtrl, 'Home address'),
                if (widget.item.email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _editField(
                    _email,
                    'Google email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _dateEditor('Date of birth', _birth, (v) => _birth = v),
                  _dateEditor('Work started on', _started, (v) => _started = v),
                ],
                const SizedBox(height: 12),
                _labeledDropdown(
                  label: 'Specialist category',
                  child: DropdownButtonFormField<String>(
                    initialValue: _specialistCategory,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items:
                        <String>{
                              ...categories,
                              if (_specialistCategory != null)
                                _specialistCategory!,
                            }
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(growable: false),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                if (widget.item.onlineSynced &&
                    _isManager &&
                    !widget.item.isManager) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _managerPin,
                    obscureText: true,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _inputDecoration().copyWith(
                      labelText: '4-digit manager PIN',
                      hintText: 'Give this PIN to the employee',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Employee active',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 16),
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    key: const Key('employee-save-error'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 12),
                ],
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
                    onPressed: _saving ? null : () => _save(store),
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : mustComplete
                          ? 'Save profile'
                          : 'Save Changes',
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
                if (widget.item.email.isNotEmpty)
                  _viewRow('Google email', _email.text),
                if (_birth != null)
                  _viewRow(
                    'Date of birth',
                    '${_birth!.day}/${_birth!.month}/${_birth!.year}',
                  ),
                if (_started != null)
                  _viewRow(
                    'Experience',
                    PersonalProfile(
                      code: '',
                      phone: '',
                      workStartedOn: _started,
                    ).experienceAt(DateTime.now()),
                  ),
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
          enabled: !_saving,
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
    if (_saving) return;
    final workspace = context.read<BusinessWorkspace?>();
    final repository = widget.repository ?? workspace?.repository;
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final phone = PkPhone.normalize(_phoneCtrl.text);
    final cnic = _cnicCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final speciality = _specialityCtrl.text.trim();

    if (first.isEmpty) return _fail('Enter the employee’s first name.');
    if (last.isEmpty && !widget.item.onlineSynced) {
      return _fail('Enter the employee’s last name.');
    }
    if (!PkPhone.isValid(phone)) {
      return _fail('Enter an 11-digit employee phone number starting with 03.');
    }
    if (!_isValidCnic(cnic)) {
      return _fail('Enter the employee’s 13-digit CNIC.');
    }
    if (address.isEmpty) return _fail('Enter the employee’s home address.');
    if (_email.text.trim().isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      return _fail('Enter a valid Google email address.');
    }
    if (_birth != null && _started != null && !_started!.isAfter(_birth!)) {
      return _fail('Work started must be after the date of birth.');
    }
    final managerChanged =
        widget.item.onlineSynced && _isManager != widget.item.isManager;
    if (managerChanged &&
        _isManager &&
        !RegExp(r'^\d{4}$').hasMatch(_managerPin.text)) {
      return _fail('Set a 4-digit manager PIN.');
    }

    final cnicDigits = cnic.replaceAll(RegExp(r'[^0-9]'), '');
    for (final other in store.all) {
      if (other.id == widget.item.id) continue;
      final otherCnic = other.cnicNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (otherCnic.isNotEmpty && otherCnic == cnicDigits) {
        _fail('Another employee already uses this CNIC.');
        return;
      }
      final otherPhone = PkPhone.normalize(other.phoneNumber);
      if (otherPhone.isNotEmpty && otherPhone == phone) {
        _fail('Another employee already uses this phone number.');
        return;
      }
    }

    var category = _specialistCategory?.trim();
    if (category == null || category.isEmpty) {
      _fail('Select a specialist category.');
      return;
    }
    if (category == 'Other') {
      final other = _otherCategoryCtrl.text.trim();
      if (other.isEmpty) {
        _fail('Enter the other category name.');
        return;
      }
      category = other;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (widget.item.onlineSynced && _isActive != widget.item.isActive) {
        if (repository == null) {
          throw StateError('Online workspace unavailable');
        }
        await repository.setEmployeeActive(widget.item.id, _isActive);
        if (!_isActive) _isManager = false;
      }
      if (managerChanged) {
        if (repository == null) {
          throw StateError('Online workspace unavailable');
        }
        await repository.setEmployeeManager(
          employeeId: widget.item.id,
          isManager: _isManager,
          pin: _isManager ? _managerPin.text : null,
        );
      }
      final updated = widget.item.copyWith(
        email: _email.text.trim().toLowerCase(),
        dateOfBirth: _birth,
        workStartedOn: _started,
        firstName: first,
        lastName: last,
        phoneNumber: phone,
        cnicNumber: _displayCnic(cnic),
        homeAddress: address,
        speciality: speciality,
        employeeType: category,
        isActive: _isActive,
        isManager: _isManager,
        photoBase64: _photoBase64,
        clearPhoto: _photoBase64 == null,
      );
      await store.update(updated);
      if (workspace != null) await workspace.syncEmployeeRecords();
      if (!mounted) return;
      setState(() {
        _completed = true;
        _saving = false;
      });
      ToastService.success(
        widget.requireCompletion
            ? 'Employee profile complete'
            : 'Employee updated',
        context,
      );
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        _fail(
          error is OnlineFailure
              ? error.message
              : 'Could not save the employee profile. Your changes are still here; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fail(String message) {
    setState(() => _saveError = message);
    ToastService.error(message, context);
  }

  String _displayCnic(String value) => PkCnic.display(value);
  Widget _dateEditor(
    String label,
    DateTime? value,
    ValueChanged<DateTime> change,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
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
        initialDate: value ?? DateTime(2000),
        firstDate: DateTime(1940),
        lastDate: DateTime.now(),
      );
      if (date != null && mounted) setState(() => change(date));
    },
  );
  bool _isValidCnic(String value) => PkCnic.isValid(value);
}
