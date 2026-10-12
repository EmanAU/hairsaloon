import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_agreement_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_history_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showAddForm = false;
  String _statusTab = 'All';

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+92');
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  String? _specialistCategory;
  bool _newEmployeeActive = true;

  static const List<String> _specialistCategories = <String>[
    'Men Specialist',
    'Women Specialist',
    'Kids Specialist',
    'General',
  ];

  List<EmployeeItem> get _employees =>
      context.watch<EmployeesStore>().employees;
  List<EmployeeItem> get _filteredEmployees {
    if (_statusTab == 'All') return _employees;
    if (_statusTab == 'Active') {
      return _employees.where((e) => e.isActive).toList(growable: false);
    }
    return _employees.where((e) => !e.isActive).toList(growable: false);
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
        title: Text(
          'Employees (${_employees.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
            icon: Icon(
              _showAddForm ? CupertinoIcons.xmark : CupertinoIcons.add,
            ),
            color: Colors.black,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStatusTabs(),
          const SizedBox(height: 10),
          if (_showAddForm) ...[_addForm(), const SizedBox(height: 12)],
          ..._filteredEmployees.map(
            (e) => InkWell(
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
                    builder: (_) =>
                        EmployeeHistoryScreen(employee: e, bills: bills),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _EmployeeAvatar(employeeId: e.id),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            e.fullName,
                            style: const TextStyle(
                              fontSize: 27 / 2,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if ((e.employeeType ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                e.employeeType!.trim(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          e.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: e.isActive
                                ? Colors.black
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'agreement') {
                          final updated = await Navigator.of(context)
                              .push<EmployeeItem>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EmployeeAgreementScreen(employee: e),
                                ),
                              );
                          if (updated == null) return;
                          context.read<EmployeesStore>().update(updated);
                          return;
                        }
                        if (value == 'edit') {
                          final updated = await Navigator.of(context)
                              .push<EmployeeItem>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EmployeeDetailsScreen(item: e),
                                ),
                              );
                          if (updated == null) return;
                          context.read<EmployeesStore>().update(updated);
                          return;
                        }
                        if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dContext) => AlertDialog(
                              title: const Text('Delete Employee'),
                              content: Text('Delete ${e.fullName}?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dContext).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          context.read<EmployeesStore>().delete(e.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'agreement',
                          child: Text('Agreement'),
                        ),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: const Icon(CupertinoIcons.ellipsis_vertical),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Employee',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
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
              onChanged: (value) => setState(() => _specialistCategory = value),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            _field(_specialityCtrl, 'Speciality'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _newEmployeeActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _newEmployeeActive
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    activeThumbColor: Colors.black,
                    inactiveTrackColor: Colors.grey.shade400,
                    value: _newEmployeeActive,
                    onChanged: (value) =>
                        setState(() => _newEmployeeActive = value),
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
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveEmployee,
                child: const Text(
                  'Save Employee',
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      inputFormatters: inputFormatters,
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
      validator: (v) {
        final value = (v ?? '').trim();
        if (value.isEmpty) return 'Required';
        if (hint == 'Phone Number') {
          if (!_isValidPkPhone(value)) return 'Use +92 followed by 10 digits';
        }
        if (hint == 'CNIC Number') {
          if (!_isValidCnic(value)) return 'Use format: 12345-1234567-1';
        }
        return null;
      },
    );
  }

  void _saveEmployee() {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;
    setState(() {
      context.read<EmployeesStore>().add(
        EmployeeItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          cnicNumber: _cnicCtrl.text.trim(),
          homeAddress: _addressCtrl.text.trim(),
          isActive: _newEmployeeActive,
          speciality: _specialityCtrl.text.trim(),
          employeeType: _specialistCategory?.trim(),
        ),
      );
      _firstNameCtrl.clear();
      _lastNameCtrl.clear();
      _phoneCtrl.text = '+92';
      _cnicCtrl.clear();
      _addressCtrl.clear();
      _specialityCtrl.clear();
      _specialistCategory = null;
      _showAddForm = false;
      _newEmployeeActive = true;
    });
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
            selectedColor: Colors.white,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: Colors.black,
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

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final useAsset = employeeId.hashCode.isEven;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: useAsset
          ? Image.asset(
              'assets/placeholder.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(CupertinoIcons.person_fill),
            )
          : const Icon(CupertinoIcons.person_fill, size: 24),
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
