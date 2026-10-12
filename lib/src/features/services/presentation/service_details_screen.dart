import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({super.key, required this.item});

  final ServiceItem item;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  late final TextEditingController _priceController;
  late String _category;
  late String _subcategory;
  late String _gender;
  late String _ageGroup;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(0),
    );
    _category = widget.item.category;
    _subcategory = widget.item.subcategory;
    _gender = widget.item.gender;
    _ageGroup = widget.item.ageGroup;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  List<String> get _categories => context.watch<ServicesStore>().categories;
  List<String> get _subcategories =>
      context.watch<ServicesStore>().subcategoriesFor(_category);

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.item.copyWith(
      category: _category,
      subcategory: _subcategory,
      gender: _gender,
      ageGroup: _ageGroup,
      price: double.tryParse(_priceController.text) ?? widget.item.price,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Service Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.category,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentItem.subcategory,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rs.${currentItem.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _decoration('Category'),
                    items: _categories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: _isEditing
                        ? (value) {
                            if (value == null) return;
                            setState(() {
                              _category = value;
                              final subs = _subcategories;
                              _subcategory = subs.isEmpty ? '' : subs.first;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _subcategory.isEmpty ? null : _subcategory,
                    decoration: _decoration('Subcategory'),
                    items: _subcategories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: _isEditing
                        ? (value) {
                            if (value == null) return;
                            setState(() => _subcategory = value);
                          }
                        : null,
                  ),
                  if (_subcategories.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No subcategory found for this category.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: _decoration('Gender'),
                    items: const ['Male', 'Female', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: _isEditing
                        ? (v) {
                            if (v == null) return;
                            setState(() => _gender = v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _ageGroup,
                    decoration: _decoration('Age Group'),
                    items: const ['Adult', 'Child']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: _isEditing
                        ? (v) {
                            if (v == null) return;
                            setState(() => _ageGroup = v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _inputField(
                    controller: _priceController,
                    hint: 'Price',
                    keyboardType: TextInputType.number,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing)
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
                        onPressed: _saveChanges,
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: _decoration(hint),
    );
  }

  void _saveChanges() {
    final parsedPrice = double.tryParse(_priceController.text.trim());
    if (_category.trim().isEmpty ||
        _subcategory.trim().isEmpty ||
        parsedPrice == null) {
      return;
    }

    Navigator.of(context).pop(
      widget.item.copyWith(
        category: _category,
        subcategory: _subcategory,
        gender: _gender,
        ageGroup: _ageGroup,
        price: parsedPrice,
      ),
    );
  }
}
