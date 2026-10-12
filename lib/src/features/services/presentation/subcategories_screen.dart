import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategory_services_screen.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SubcategoriesScreen extends StatefulWidget {
  const SubcategoriesScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<SubcategoriesScreen> createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends State<SubcategoriesScreen> {
  final TextEditingController _subcategoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final categories = context.read<ServicesStore>().categories;
    final requested = widget.initialCategory;
    if (requested != null && categories.contains(requested)) {
      _selectedCategory = requested;
    } else {
      _selectedCategory = categories.first;
    }
  }

  @override
  void dispose() {
    _subcategoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  List<String> get _subcategories =>
      context.watch<ServicesStore>().subcategoriesFor(_selectedCategory);

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ServicesStore>().categories;
    final subcategories = _subcategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back),
          color: Colors.black,
        ),
        title: Text(
          'Sub Categories (${subcategories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: _fieldDecoration('Select Category'),
            items: categories
                .map(
                  (item) =>
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _subcategoryController,
            decoration: _fieldDecoration('Enter Subcategory Name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration('Enter Price'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saveSubcategory,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...subcategories.map(_buildSubcategoryTile),
        ],
      ),
    );
  }

  Widget _buildSubcategoryTile(String name) {
    final price =
        context
            .watch<ServicesStore>()
            .serviceFor(category: _selectedCategory, subcategory: name)
            ?.price ??
        0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubcategoryServicesScreen(
                  category: _selectedCategory,
                  subcategory: name,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'Rs.${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditSubcategoryDialog(name);
                      return;
                    }
                    if (value == 'delete') {
                      context.read<ServicesStore>().deleteSubcategory(
                        category: _selectedCategory,
                        subcategory: name,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  icon: const Icon(CupertinoIcons.ellipsis_vertical),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Future<void> _saveSubcategory() async {
    final value = _subcategoryController.text.trim();
    final parsed = double.tryParse(_priceController.text.trim());
    if (value.isEmpty || parsed == null || parsed <= 0) {
      _showMessage('Enter valid service name and price.');
      return;
    }

    final store = context.read<ServicesStore>();
    final added = await store.addSubcategory(
      category: _selectedCategory,
      subcategory: value,
    );

    // Even if the subcategory already exists, allow updating its price.
    await store.updatePriceForSubcategory(
      category: _selectedCategory,
      subcategory: value,
      price: parsed,
    );

    if (!mounted) return;
    if (!added) {
      _showMessage('Price updated.');
    }
    _subcategoryController.clear();
    _priceController.clear();
  }

  Future<void> _showEditSubcategoryDialog(String oldName) async {
    final nameController = TextEditingController(text: oldName);
    final currentPrice =
        context
            .read<ServicesStore>()
            .serviceFor(category: _selectedCategory, subcategory: oldName)
            ?.price ??
        0.0;
    final priceController = TextEditingController(
      text: currentPrice <= 0 ? '' : currentPrice.toStringAsFixed(0),
    );

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        const radius = 6.0;
        InputDecoration fieldDecoration(String label) {
          return InputDecoration(
            labelText: label,
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
          );
        }

        return AlertDialog(
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          title: const Text(
            'Edit Service',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.black),
                decoration: fieldDecoration('Service Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: fieldDecoration('Price'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
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
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Update',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (shouldUpdate != true || !mounted) return;

    final newName = nameController.text.trim();
    final parsed = double.tryParse(priceController.text.trim());
    if (newName.isEmpty || parsed == null || parsed <= 0) {
      _showMessage('Enter valid service name and price.');
      return;
    }

    final renamed = await context.read<ServicesStore>().renameSubcategory(
      category: _selectedCategory,
      oldName: oldName,
      newName: newName,
    );
    if (!renamed) {
      _showMessage('Unable to update. Name may already exist.');
      return;
    }
    await context.read<ServicesStore>().updatePriceForSubcategory(
      category: _selectedCategory,
      subcategory: newName,
      price: parsed,
    );
    _showMessage('Subcategory updated.');
  }

  void _showMessage(String message) {
    ToastService.info(message);
  }
}
