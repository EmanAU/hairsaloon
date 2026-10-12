import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({super.key, required this.item});

  final EmployeeItem item;

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cnicCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _specialityCtrl;
  String? _specialistCategory;
  bool _editing = false;
  late bool _isActive;

  static const List<String> _specialistCategories = <String>[
    'Men Specialist',
    'Women Specialist',
    'Kids Specialist',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.item.firstName);
    _lastNameCtrl = TextEditingController(text: widget.item.lastName);
    _phoneCtrl = TextEditingController(text: widget.item.phoneNumber);
    _cnicCtrl = TextEditingController(text: widget.item.cnicNumber);
    _addressCtrl = TextEditingController(text: widget.item.homeAddress);
    _specialityCtrl = TextEditingController(text: widget.item.speciality ?? '');
    _specialistCategory = (widget.item.employeeType ?? '').trim().isEmpty
        ? null
        : widget.item.employeeType!.trim();
    _isActive = widget.item.isActive;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _addressCtrl.dispose();
    _specialityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Employee Details',
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
          _field(_firstNameCtrl, 'First Name'),
          const SizedBox(height: 10),
          _field(_lastNameCtrl, 'Last Name'),
          const SizedBox(height: 10),
          _field(
            _phoneCtrl,
            'Phone Number',
            keyboardType: TextInputType.phone,
            inputFormatters: [_PhonePkFormatter()],
          ),
          const SizedBox(height: 10),
          _field(
            _cnicCtrl,
            'CNIC Number',
            keyboardType: TextInputType.number,
            inputFormatters: [_CnicFormatter()],
          ),
          const SizedBox(height: 10),
          _field(_addressCtrl, 'Home Address'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _specialistCategory,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Specialist Category',
              hintStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
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
            items: _specialistCategories
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
            onChanged: _editing
                ? (v) => setState(() => _specialistCategory = v)
                : null,
          ),
          const SizedBox(height: 10),
          _field(_specialityCtrl, 'Speciality'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: AppColors.primary,
            title: const Text(
              'Employee Active',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
            value: _isActive,
            onChanged: _editing
                ? (value) => setState(() => _isActive = value)
                : null,
          ),
          const SizedBox(height: 14),
          if (_editing)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: const Text('Save Changes'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      enabled: _editing,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
      ),
    );
  }

  void _save() {
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
      return;
    }

    final updated = widget.item.copyWith(
      firstName: first,
      lastName: last,
      phoneNumber: phone,
      cnicNumber: cnic,
      homeAddress: address,
      speciality: speciality,
      employeeType: _specialistCategory?.trim(),
      isActive: _isActive,
    );
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
