import 'package:flutter/material.dart';
import '../domain/entities/bill.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.employees,
    required this.paymentMethods,
    required this.lines,
    required this.total,
    required this.customer,
    required this.onSave,
  });
  final List<String> employees, paymentMethods;
  final List<BillLine> lines;
  final double total;
  final String customer;
  final Future<Bill> Function(String employee, String payment) onSave;
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _form = GlobalKey<FormState>();
  String? _employee, _payment, _error;
  bool _saving = false;
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bill = await widget.onSave(_employee!, _payment!);
      if (mounted) Navigator.pop(context, bill);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this bill. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel checkout',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  widget.customer,
                  style: const TextStyle(color: Color(0xFF738093)),
                ),
                const SizedBox(height: 18),
                for (final line in widget.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(line.serviceName)),
                        Text('Rs ${line.total.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                const Divider(height: 26),
                DropdownButtonFormField<String>(
                  key: const ValueKey('checkout-employee'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Employee',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.employees
                      .toSet()
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select employee' : null,
                  onChanged: _saving ? null : (value) => _employee = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('checkout-payment'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.paymentMethods
                      .toSet()
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select payment method' : null,
                  onChanged: _saving ? null : (value) => _payment = value,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Rs ${widget.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC7F52B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(18),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save & show receipt'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
