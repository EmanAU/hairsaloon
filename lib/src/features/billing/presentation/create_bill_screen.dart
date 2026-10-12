import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({
    super.key,
    required this.customerName,
    required this.customerPhone,
  });

  final String customerName;
  final String customerPhone;

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  late final Map<int, TextEditingController> _amountControllers;
  final Set<int> _selectedServiceIndexes = <int>{};
  late String _employee;
  String _paymentType = 'Cash';

  @override
  void initState() {
    super.initState();
    final activeEmployees = context
        .read<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .map((e) => e.fullName)
        .where((name) => name.isNotEmpty)
        .toList();
    _employee = activeEmployees.isNotEmpty
        ? activeEmployees.first
        : 'Unassigned';
    final services = context.read<ServicesStore>().services;
    _amountControllers = {
      for (int i = 0; i < services.length; i++)
        i: TextEditingController(text: services[i].price.toStringAsFixed(0)),
    };
  }

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<BillLine> get _selectedLines {
    final services = context.read<ServicesStore>().services;
    return _selectedServiceIndexes.map((i) {
      final svc = services[i];
      final amount =
          double.tryParse(_amountControllers[i]?.text ?? '') ?? svc.price;
      return BillLine(
        serviceName: svc.subcategory,
        price: amount,
        qty: 1,
        tag: svc.category,
      );
    }).toList();
  }

  double get _subTotal =>
      _selectedLines.fold(0, (sum, line) => sum + line.total);
  double get _taxPercent => context.read<SettingsStore>().taxRate;
  double get _taxAmount => (_subTotal * _taxPercent) / 100;
  double get _grandTotal => _subTotal + _taxAmount;

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ServicesStore>().services;
    final employeeOptions = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .map((e) => e.fullName)
        .where((name) => name.isNotEmpty)
        .toList();
    if (employeeOptions.isEmpty) {
      employeeOptions.add('Unassigned');
    }
    if (!employeeOptions.contains(_employee)) {
      _employee = employeeOptions.first;
    }
    return AdaptivePage(
      form: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3),
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.back, color: Colors.black),
          ),
          title: const Text(
            'Create Bill',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Sub Total: ${_subTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tax: ${_taxPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: Rs.${_grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.customerName.isEmpty
                          ? widget.customerPhone
                          : '${widget.customerName} • ${widget.customerPhone}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _employee,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.black,
                    ),
                    decoration: _smallDecoration('Select Employee'),
                    items: employeeOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _employee = v ?? _employee),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentType,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.black,
                    ),
                    decoration: _smallDecoration('Payment Type'),
                    items: const ['Cash']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _paymentType = v ?? _paymentType),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveBill,
                      child: const Text(
                        'Save Bill',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: services.length,
                itemBuilder: (context, i) {
                  final s = services[i];
                  final selected = _selectedServiceIndexes.contains(i);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedServiceIndexes.add(i);
                              } else {
                                _selectedServiceIndexes.remove(i);
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.subcategory,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                s.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _amountControllers[i],
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixText: 'Rs.',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _smallDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _saveBill() async {
    if (_selectedLines.isEmpty) {
      _showMessage('Select at least one service.');
      return;
    }
    final bill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      employeeName: _employee,
      paymentType: _paymentType,
      lines: _selectedLines,
      subTotal: _subTotal,
      taxPercent: _taxPercent,
      taxAmount: _taxAmount,
      grandTotal: _grandTotal,
    );
    await context.read<BillingStore>().addBill(bill);
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.billDetails, arguments: bill.id);
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
