import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/customer_contact.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _headerFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _servicesSectionKey = GlobalKey();
  bool _hidePhoneSuggestions = false;
  String _selectedCategory = 'All';
  final Set<String> _selectedServiceIds = <String>{};
  final Map<String, double> _servicePricesById = <String, double>{};
  String? _employee;
  String? _paymentType;
  bool _didAttemptSave = false;
  CustomerContact? _selectedCustomer;

  List<String> get _categories {
    final values =
        context
            .watch<ServicesStore>()
            .services
            .map((service) => service.category)
            .toSet()
            .toList()
          ..sort();
    return <String>['All', ...values];
  }

  List<BillLine> _selectedLines(List<ServiceItem> services) {
    final selectedServices = services
        .where((s) => _selectedServiceIds.contains(s.id))
        .toList(growable: false);
    return selectedServices
        .map((service) {
          final amount = _servicePricesById[service.id] ?? service.price;
          return BillLine(
            serviceName: service.subcategory,
            price: amount,
            qty: 1,
            tag: service.category,
          );
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _employee = null;
    _paymentType = null;
    for (final service in context.read<ServicesStore>().services) {
      _servicePricesById[service.id] = service.price;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Keep content above the bottom navigation bar (DashboardShell has extendBody: true).
    final bottomSafeSpace = bottomInset + 120;
    final services = context.watch<ServicesStore>().services;
    final activeEmployees = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .where((e) => e.fullName.trim().isNotEmpty)
        .toList(growable: false);
    final employeeOptions = activeEmployees.isEmpty
        ? <String>['Unassigned']
        : activeEmployees.map((e) => e.fullName).toList(growable: false);
    if (_employee != null && !employeeOptions.contains(_employee)) {
      _employee = null;
    }
    final customerPhone = _phoneCtrl.text.trim();
    final phoneMatches = _customerMatches(customerPhone);
    final showPhoneMatches =
        !_hidePhoneSuggestions &&
        customerPhone.isNotEmpty &&
        phoneMatches.isNotEmpty;
    final selectedLines = _selectedLines(services);
    final subTotal = selectedLines.fold<double>(
      0,
      (sum, line) => sum + line.total,
    );
    final taxPercent = context.watch<SettingsStore>().taxRate;
    final taxAmount = (subTotal * taxPercent) / 100;
    final grandTotal = subTotal + taxAmount;
    final hasCustomerInfo = customerPhone.isNotEmpty;
    final customerInfoText = _selectedCustomer == null
        ? 'Customer Phone: $customerPhone'
        : 'Customer: ${_selectedCustomer!.displayLabel}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Billing',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.only(bottom: bottomSafeSpace.toDouble()),
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.cart,
                      size: 22,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_selectedServiceIds.length.toString().padLeft(2, '0')} services used',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 30,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.savedBills),
                        child: const Text(
                          'Saved Bills',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Sub Total : ${subTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tax : ${taxPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total : Rs.${grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        style: const TextStyle(fontSize: 12),
                        keyboardType: TextInputType.phone,
                        onChanged: (_) {
                          if (!mounted) return;
                          final phone = _phoneCtrl.text.trim();
                          final exact = context
                              .read<BillingStore>()
                              .getCustomerContactByPhone(phone);
                          setState(() {
                            _hidePhoneSuggestions = false;
                            _selectedCustomer = exact;
                          });
                        },
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          if (_hasKnownPhone(value)) return;
                          _promptAddCustomer(initialPhone: value.trim());
                        },
                        decoration: _smallDecoration(
                          'Enter Customer Phone Number',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _promptAddCustomer,
                        child: const Text(
                          'Add New',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showPhoneMatches) ...[
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: phoneMatches
                          .take(4)
                          .map(
                            (customer) => InkWell(
                              onTap: () {
                                setState(() {
                                  _phoneCtrl.text = customer.phone;
                                  _hidePhoneSuggestions = true;
                                  _selectedCustomer = customer;
                                });
                                FocusScope.of(context).unfocus();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.search,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        customer.displayLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
                if (hasCustomerInfo) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      customerInfoText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Form(
                        key: _headerFormKey,
                        autovalidateMode: _didAttemptSave
                            ? AutovalidateMode.always
                            : AutovalidateMode.disabled,
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _employee,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                iconSize: 16,
                                decoration: _smallDecoration(
                                  'Employee (required)',
                                ),
                                hint: const Text(
                                  'Select Employee',
                                  style: TextStyle(fontSize: 11),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Select employee';
                                  }
                                  return null;
                                },
                                selectedItemBuilder: (context) =>
                                    employeeOptions
                                        .map(
                                          (name) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _formatEmployeeLabel(
                                                name,
                                                activeEmployees:
                                                    activeEmployees,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                items: employeeOptions
                                    .map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(
                                          _formatEmployeeLabel(
                                            name,
                                            activeEmployees: activeEmployees,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _employee = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _paymentType,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                iconSize: 16,
                                decoration: _smallDecoration(
                                  'Payment (required)',
                                ),
                                hint: const Text(
                                  'Select Payment',
                                  style: TextStyle(fontSize: 11),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Select payment';
                                  }
                                  return null;
                                },
                                selectedItemBuilder: (context) =>
                                    const ['Cash', 'Card', 'Online']
                                        .map(
                                          (type) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              type,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                items: const ['Cash', 'Card', 'Online']
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _paymentType = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 96,
                              height: 44,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _saveBill,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Save Bill',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final category = _categories[i];
                final selected = _selectedCategory == category;
                return _TagChip(
                  text: category,
                  selected: selected,
                  onTap: () => setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            key: _servicesSectionKey,
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: const Text(
              'Available Services',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedCategory == 'All'
                ? services.length
                : services.where((s) => s.category == _selectedCategory).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final filteredServices = _selectedCategory == 'All'
                  ? services
                  : services
                        .where((s) => s.category == _selectedCategory)
                        .toList(growable: false);
              final service = filteredServices[index];
              final selected = _selectedServiceIds.contains(service.id);
              final price = _servicePricesById[service.id] ?? service.price;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedServiceIds.remove(service.id);
                    } else {
                      _selectedServiceIds.add(service.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Colors.black
                          : Colors.grey.withValues(alpha: 0.2),
                      width: selected ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: const Alignment(0, 0.3),
                          child: Text(
                            service.subcategory,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Transform.translate(
                        offset: const Offset(0, -2),
                        child: Text(
                          'Rs.${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 6),
                        const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 15,
                          color: Colors.black,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _smallDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _promptAddCustomer({String? initialPhone}) async {
    final prefillPhone = (initialPhone ?? _phoneCtrl.text).trim();

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: prefillPhone);
    try {
      final result = await showDialog<CustomerContact?>(
        context: context,
        builder: (dialogContext) {
          const radius = 6.0;
          return AlertDialog(
            backgroundColor: AppColors.primary,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            title: const Text(
              'Add Customer',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    labelStyle: const TextStyle(color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Customer Number',
                    labelStyle: const TextStyle(color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (phone.isEmpty) return;
                  Navigator.of(
                    dialogContext,
                  ).pop(CustomerContact(name: name, phone: phone));
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) return;

      await context.read<BillingStore>().addOrUpdateCustomerContact(
        name: result.name,
        phone: result.phone,
      );
      if (!mounted) return;

      setState(() {
        _phoneCtrl.text = result.phone;
        _hidePhoneSuggestions = true;
        _selectedCustomer = result;
      });

      FocusScope.of(context).unfocus();
      _scrollToServices();
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  Future<void> _saveBill() async {
    setState(() => _didAttemptSave = true);
    final headerState = _headerFormKey.currentState;
    if (headerState == null || !headerState.validate()) {
      _showMessage('Please select employee and payment method.');
      return;
    }
    final services = context.read<ServicesStore>().services;
    final selectedLines = _selectedLines(services);
    if (selectedLines.isEmpty) {
      _showMessage('Select at least one service.');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !_hasKnownPhone(phone)) {
      await _promptAddCustomer(initialPhone: phone);
      if (!mounted) return;
      final updatedPhone = _phoneCtrl.text.trim();
      if (updatedPhone.isNotEmpty && !_hasKnownPhone(updatedPhone)) {
        return;
      }
    }
    final settingsStore = context.read<SettingsStore>();
    final subTotal = selectedLines.fold<double>(
      0,
      (sum, line) => sum + line.total,
    );
    final taxPercent = settingsStore.taxRate;
    final taxAmount = (subTotal * taxPercent) / 100;
    final grandTotal = subTotal + taxAmount;

    final contact = phone.isEmpty
        ? null
        : context.read<BillingStore>().getCustomerContactByPhone(phone);
    final bill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      customerName: contact?.name.trim() ?? '',
      customerPhone: phone,
      employeeName: _employee ?? '',
      paymentType: _paymentType ?? '',
      lines: selectedLines,
      subTotal: subTotal,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );
    await context.read<BillingStore>().addBill(bill);
    if (!mounted) return;
    ToastService.success('Bill saved successfully');
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.billDetails, arguments: bill.id).then((_) {
      if (!mounted) return;
      _resetForNewBill();
    });
  }

  List<CustomerContact> _customerMatches(String query) {
    final matches = context.read<BillingStore>().searchCustomerContacts(query);
    if (matches.isNotEmpty) return matches;

    final phones = context.read<BillingStore>().searchCustomerPhones(query);
    return phones
        .map((phone) => CustomerContact(name: '', phone: phone))
        .toList(growable: false);
  }

  bool _hasKnownPhone(String value) {
    return context.read<BillingStore>().hasKnownCustomerPhone(value);
  }

  void _resetForNewBill() {
    setState(() {
      _phoneCtrl.clear();
      _selectedCategory = 'All';
      _selectedServiceIds.clear();
      _employee = null;
      _paymentType = null;
      _didAttemptSave = false;
      _selectedCustomer = null;
    });
  }

  void _scrollToServices() {
    final targetContext = _servicesSectionKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  void _showMessage(String message) {
    ToastService.info(message);
  }

  String _formatEmployeeLabel(
    String fullName, {
    required List<EmployeeItem> activeEmployees,
  }) {
    final match = activeEmployees.where((e) => e.fullName == fullName).toList();
    if (match.isEmpty) return fullName;
    final type = (match.first.employeeType ?? '').trim();
    if (type.isEmpty) return fullName;
    return '$fullName • $type';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
