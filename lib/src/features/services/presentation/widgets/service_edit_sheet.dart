import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

typedef ServiceEditResult = ({String name, double price});

Future<ServiceEditResult?> showServiceEditSheet({
  required BuildContext context,
  required String title,
  required String nameLabel,
  required String name,
  required double price,
}) {
  return showAppSheet<ServiceEditResult>(
    context: context,
    builder: (_) => _ServiceEditSheet(
      title: title,
      nameLabel: nameLabel,
      name: name,
      price: price,
    ),
  );
}

class _ServiceEditSheet extends StatefulWidget {
  const _ServiceEditSheet({
    required this.title,
    required this.nameLabel,
    required this.name,
    required this.price,
  });

  final String title;
  final String nameLabel;
  final String name;
  final double price;

  @override
  State<_ServiceEditSheet> createState() => _ServiceEditSheetState();
}

class _ServiceEditSheetState extends State<_ServiceEditSheet> {
  late final _nameCtrl = TextEditingController(text: widget.name);
  late final _priceCtrl = TextEditingController(
    text: widget.price <= 0 ? '' : widget.price.toStringAsFixed(0),
  );
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      setState(() => _error = 'Enter a valid name and price');
      return;
    }
    Navigator.of(context).pop((name: name, price: price));
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: widget.title,
      subtitle: widget.name,
      icon: CupertinoIcons.pencil,
      confirmLabel: 'Update',
      onConfirm: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13.5),
            decoration: appSheetInputDecoration(widget.nameLabel),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 13.5),
            decoration: appSheetInputDecoration('Price'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
