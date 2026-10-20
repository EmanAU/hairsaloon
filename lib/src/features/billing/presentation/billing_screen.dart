import 'billing_customer_picker.dart';
import 'checkout_dialog.dart';
import 'receipt_dialog.dart';
import 'receipt_share_mixin.dart';
import '../../business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/customer_contact.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'tablet_billing_view.dart';
import 'mobile_billing_screen.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600
      ? const _TabletBillingScreen()
      : const MobileBillingScreen();
}

class _TabletBillingScreen extends StatefulWidget {
  const _TabletBillingScreen();

  @override
  State<_TabletBillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<_TabletBillingScreen> {
  final _phoneCtrl = TextEditingController();
  String _selectedCategory = 'All';
  final Set<String> _selectedServiceIds = <String>{};
  final Map<String, double> _servicePricesById = <String, double>{};
  CustomerContact? _selectedCustomer;
  BillDiscountType _discountType = BillDiscountType.none;
  double _discountValue = 0;
  String _search = '';
  bool _searchingCustomer = false;
  bool _saving = false;

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
    for (final service in context.read<ServicesStore>().services) {
      _servicePricesById[service.id] = service.price;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ServicesStore>().services;
    final selectedLines = _selectedLines(services);
    final subTotal = selectedLines.fold<double>(
      0,
      (sum, line) => sum + line.total,
    );
    final taxPercent = context.watch<SettingsStore>().taxRate;
    final totals = BillTotals.compute(
      subTotal: subTotal,
      taxPercent: taxPercent,
      discountType: _discountType,
      discountValue: _discountValue,
    );
    return TabletBillingView(
      services: services
          .where(
            (service) =>
                (_selectedCategory == 'All' ||
                    service.category == _selectedCategory) &&
                '${service.subcategory} ${service.category}'
                    .toLowerCase()
                    .contains(_search.toLowerCase()),
          )
          .toList(),
      selectedServices: services
          .where((service) => _selectedServiceIds.contains(service.id))
          .toList(),
      categories: _categories,
      category: _selectedCategory,
      onCategory: (value) => setState(() => _selectedCategory = value),
      onSearch: (value) => setState(() => _search = value),
      priceOf: (service) => _servicePricesById[service.id] ?? service.price,
      onToggle: (service) => setState(() {
        if (!_selectedServiceIds.add(service.id)) {
          _selectedServiceIds.remove(service.id);
        }
      }),
      onEditPrice: _editPrice,
      subTotal: subTotal,
      tax: totals.taxAmount,
      taxPercent: taxPercent,
      discount: totals.discountAmount,
      total: totals.grandTotal,
      onDiscount: () => _openDiscountSheet(subTotal),
      onClear: _resetForNewBill,
      onCheckout: _saving ? null : _checkout,
      onSavedBills: () => Navigator.pushNamed(context, AppRoutes.savedBills),
      onAddService: () => Navigator.pushNamed(context, AppRoutes.newService),
      customer: BillingCustomerPicker(
        searching: _searchingCustomer,
        controller: _phoneCtrl,
        selected: _selectedCustomer,
        matches: _customerMatches(_phoneCtrl.text.trim()),
        onMode: (searching) => setState(() {
          _searchingCustomer = searching;
          _selectedCustomer = null;
          _phoneCtrl.clear();
        }),
        onChanged: (value) => setState(
          () => _selectedCustomer = context
              .read<BillingStore>()
              .getCustomerContactByPhone(value.trim()),
        ),
        onSelect: _applyCustomer,
        onAdd: _promptAddCustomer,
      ),
    );
  }

  Future<void> _editPrice(ServiceItem service) async {
    final controller = TextEditingController(
      text: (_servicePricesById[service.id] ?? service.price).toStringAsFixed(
        2,
      ),
    );
    final form = GlobalKey<FormState>();
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Price · ${service.subcategory}'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price for this bill'),
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              return parsed == null || !parsed.isFinite || parsed < 0
                  ? 'Enter a valid price'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, double.parse(controller.text));
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    // Wait until the dialog's closing animation releases its text field.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (price != null && mounted) {
      setState(() => _servicePricesById[service.id] = price);
    }
  }

  void _applyCustomer(CustomerContact customer) {
    setState(() {
      _selectedCustomer = customer;
      _phoneCtrl.text = customer.phone;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _promptAddCustomer({String? initialPhone}) async {
    final prefillPhone = (initialPhone ?? _phoneCtrl.text).trim();
    final existing = context.read<BillingStore>().getCustomerContactByPhone(
      prefillPhone,
    );
    if (existing != null) {
      _applyCustomer(existing);
      return;
    }
    final result = await showAppSheet<CustomerContact>(
      context: context,
      builder: (_) => _AddCustomerSheet(initialPhone: prefillPhone),
    );
    if (!mounted || result == null) return;

    await context.read<BillingStore>().addOrUpdateCustomerContact(
      name: result.name,
      phone: result.phone,
    );
    if (!mounted) return;

    setState(() {
      _phoneCtrl.text = result.phone;
      _selectedCustomer = result;
    });

    FocusScope.of(context).unfocus();
  }

  Future<Bill> _saveBill(String employee, String payment) async {
    final selectedLines = _selectedLines(
      context.read<ServicesStore>().services,
    );
    final phone = _searchingCustomer ? (_selectedCustomer?.phone ?? '') : '';
    final settingsStore = context.read<SettingsStore>();
    final subTotal = selectedLines.fold<double>(
      0,
      (sum, line) => sum + line.total,
    );
    final taxPercent = settingsStore.taxRate;
    final totals = BillTotals.compute(
      subTotal: subTotal,
      taxPercent: taxPercent,
      discountType: _discountType,
      discountValue: _discountValue,
    );
    final hasDiscount = totals.discountAmount > 0;

    final contact = phone.isEmpty
        ? null
        : context.read<BillingStore>().getCustomerContactByPhone(phone);
    final bill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      customerName: contact?.name.trim() ?? '',
      customerPhone: phone,
      employeeName: employee,
      paymentType: payment,
      lines: selectedLines,
      subTotal: subTotal,
      taxPercent: taxPercent,
      taxAmount: totals.taxAmount,
      grandTotal: totals.grandTotal,
      discountType: hasDiscount ? _discountType : BillDiscountType.none,
      discountValue: hasDiscount ? _discountValue : 0,
      discountAmount: totals.discountAmount,
    );
    await context.read<BillingStore>().addBill(bill);
    return bill;
  }

  Future<void> _checkout() async {
    if (_saving) return;
    final lines = _selectedLines(context.read<ServicesStore>().services);
    if (lines.isEmpty) {
      _showMessage('Select at least one service.');
      return;
    }
    if (_searchingCustomer && _selectedCustomer == null) {
      _showMessage(
        'Select a saved customer, add a new customer, or choose Walk-in.',
      );
      return;
    }
    final employees = context
        .read<EmployeesStore>()
        .employees
        .where(
          (employee) =>
              employee.isActive && employee.fullName.trim().isNotEmpty,
        )
        .map((employee) => employee.fullName)
        .toList();
    final settings = context.read<SettingsStore>();
    final business = ReceiptBusinessInfo.from(
      context.read<BusinessProfileNotifier>().profile,
    );
    final currency = settings.currencyCode;
    final totals = BillTotals.compute(
      subTotal: lines.fold<double>(0, (sum, line) => sum + line.total),
      taxPercent: settings.taxRate,
      discountType: _discountType,
      discountValue: _discountValue,
    );
    setState(() => _saving = true);
    try {
      final bill = await showDialog<Bill>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CheckoutDialog(
          employees: employees.isEmpty ? ['Unassigned'] : employees,
          paymentMethods: settings.paymentMethods,
          lines: lines,
          total: totals.grandTotal,
          customer: _selectedCustomer?.displayLabel ?? 'Walk-in Customer',
          onSave: _saveBill,
        ),
      );
      if (bill == null || !mounted) return;
      _resetForNewBill();
      final details = await showDialog<bool>(
        context: context,
        builder: (_) =>
            ReceiptDialog(bill: bill, business: business, currency: currency),
      );
      if (details == true && mounted) {
        await Navigator.pushNamed(
          context,
          AppRoutes.billDetails,
          arguments: bill.id,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<CustomerContact> _customerMatches(String query) {
    final store = context.read<BillingStore>();
    final matches = store.searchCustomerContacts(query);
    if (matches.isNotEmpty) {
      return matches
          .map((c) => store.getCustomerContactByPhone(c.phone) ?? c)
          .toList(growable: false);
    }

    final phones = store.searchCustomerPhones(query);
    return phones
        .map(
          (phone) =>
              store.getCustomerContactByPhone(phone) ??
              CustomerContact(name: '', phone: phone),
        )
        .toList(growable: false);
  }

  void _resetForNewBill() {
    setState(() {
      _phoneCtrl.clear();
      _searchingCustomer = false;
      _selectedCategory = 'All';
      _selectedServiceIds.clear();
      _servicePricesById.clear();
      _selectedCustomer = null;
      _discountType = BillDiscountType.none;
      _discountValue = 0;
    });
  }

  Future<void> _openDiscountSheet(double subTotal) async {
    final result = await showAppSheet<({BillDiscountType type, double value})>(
      context: context,
      builder: (_) => _DiscountSheet(
        initialType: _discountType,
        initialValue: _discountValue,
        subTotal: subTotal,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _discountType = result.type;
      _discountValue = result.type == BillDiscountType.none ? 0 : result.value;
    });
  }

  void _showMessage(String message) {
    ToastService.info(message);
  }
}

String _formatDiscountValue(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

class _DiscountSheet extends StatefulWidget {
  const _DiscountSheet({
    required this.initialType,
    required this.initialValue,
    required this.subTotal,
  });

  final BillDiscountType initialType;
  final double initialValue;
  final double subTotal;

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late BillDiscountType _type = widget.initialType == BillDiscountType.none
      ? BillDiscountType.percent
      : widget.initialType;
  late final _valueCtrl = TextEditingController(
    text: widget.initialValue > 0
        ? _formatDiscountValue(widget.initialValue)
        : '',
  );
  String? _error;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_valueCtrl.text.trim()) ?? 0;

  void _apply() {
    final value = _value;
    if (value <= 0) {
      setState(() => _error = 'Enter a discount greater than 0');
      return;
    }
    if (_type == BillDiscountType.percent && value > 100) {
      setState(() => _error = 'Percentage cannot exceed 100');
      return;
    }
    Navigator.of(context).pop((type: _type, value: value));
  }

  void _remove() {
    Navigator.of(context).pop((type: BillDiscountType.none, value: 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final preview = BillTotals.compute(
      subTotal: widget.subTotal,
      taxPercent: 0,
      discountType: _type,
      discountValue: _value,
    ).discountAmount;
    final hasExisting = widget.initialType != BillDiscountType.none;

    return AppSheetBody(
      title: 'Discount',
      subtitle: 'Optional. Applied before tax.',
      icon: CupertinoIcons.tag,
      cancelLabel: hasExisting ? 'Remove' : 'Cancel',
      onCancel: hasExisting ? _remove : null,
      confirmLabel: 'Apply',
      onConfirm: _apply,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _typeOption(BillDiscountType.percent, 'Percentage (%)'),
                _typeOption(BillDiscountType.amount, 'Amount (Rs)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 13.5),
            decoration:
                appSheetInputDecoration(
                  _type == BillDiscountType.percent
                      ? 'Discount percentage'
                      : 'Discount amount',
                  prefixText: _type == BillDiscountType.amount ? 'Rs. ' : null,
                ).copyWith(
                  suffixText: _type == BillDiscountType.percent ? '%' : null,
                  errorText: _error,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Discount on this bill',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '- Rs.${preview.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeOption(BillDiscountType type, String label) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.surface : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCustomerSheet extends StatefulWidget {
  const _AddCustomerSheet({required this.initialPhone});

  final String initialPhone;

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _nameCtrl = TextEditingController();
  late final _phoneCtrl = TextEditingController(
    text: widget.initialPhone.trim().isEmpty
        ? PkPhone.prefix
        : PkPhone.normalize(widget.initialPhone),
  );
  String? _phoneError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = PkPhone.normalize(_phoneCtrl.text);
    final error = PkPhone.validationError(phone);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }
    Navigator.of(
      context,
    ).pop(CustomerContact(name: _nameCtrl.text.trim(), phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Add Customer',
      subtitle: 'Save the customer for faster billing next time.',
      icon: CupertinoIcons.person_add,
      confirmLabel: 'Save Customer',
      onConfirm: _submit,
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: widget.initialPhone.isNotEmpty,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13.5),
            decoration: appSheetInputDecoration('Customer Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [PkPhoneInputFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            style: const TextStyle(fontSize: 13.5),
            decoration: appSheetInputDecoration(
              'Customer Number (+923462254477)',
            ).copyWith(errorText: _phoneError),
          ),
        ],
      ),
    );
  }
}
