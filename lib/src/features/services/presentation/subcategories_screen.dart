import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategory_services_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/widgets/service_edit_sheet.dart';
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
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    final categories = context.read<ServicesStore>().categories;
    final requested = widget.initialCategory;
    if (requested != null && categories.contains(requested)) {
      _selectedCategory = requested;
    } else if (categories.isNotEmpty) {
      _selectedCategory = categories.first;
    } else {
      _selectedCategory = '';
    }
  }

  @override
  void dispose() {
    _subcategoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  List<String> get _subcategories => _selectedCategory.isEmpty
      ? const <String>[]
      : context.watch<ServicesStore>().subcategoriesFor(_selectedCategory);

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ServicesStore>().categories;
    final subcategories = _subcategories;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: Text(
          'Subcategories (${subcategories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add subcategory',
            onPressed: categories.isEmpty
                ? null
                : () => setState(() => _showAddForm = !_showAddForm),
            icon: Icon(
              _showAddForm ? CupertinoIcons.xmark : CupertinoIcons.add,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'Add a category first from Categories.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          : ListView(
              padding: SafeScrollPadding.of(
                context,
                left: 12,
                top: 14,
                right: 12,
                bottom: 24,
              ),
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : categories.first,
                  decoration: _fieldDecoration('Select category'),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
                ),
                if (_showAddForm) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E1E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add subcategory',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Will be added under $_selectedCategory',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Subcategory name',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _subcategoryController,
                          decoration: _fieldDecoration('e.g. Haircut'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Price (Rs.)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration('e.g. 500'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _saveSubcategory,
                            child: const Text(
                              'Save subcategory',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (subcategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text(
                        'No subcategories yet.\nTap + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E1E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Rs.${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _showEditSubcategoryDialog(name);
                      return;
                    }
                    if (value == 'delete') {
                      final store = context.read<ServicesStore>();
                      final confirm = await showAppConfirmDialog(
                        context: context,
                        title: 'Delete Subcategory',
                        message: 'Delete "$name" and its services?',
                        confirmLabel: 'Delete',
                        isDestructive: true,
                      );
                      if (confirm != true || !mounted) return;
                      await store.deleteSubcategory(
                        category: _selectedCategory,
                        subcategory: name,
                      );
                      ToastService.success('Subcategory deleted');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 18),
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
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Future<void> _saveSubcategory() async {
    final value = _subcategoryController.text.trim();
    final parsed = double.tryParse(_priceController.text.trim());
    if (value.isEmpty || parsed == null || parsed <= 0) {
      ToastService.error('Enter valid subcategory name and price.');
      return;
    }

    final store = context.read<ServicesStore>();
    final added = await store.addSubcategory(
      category: _selectedCategory,
      subcategory: value,
    );

    await store.updatePriceForSubcategory(
      category: _selectedCategory,
      subcategory: value,
      price: parsed,
    );

    if (!mounted) return;
    ToastService.success(added ? 'Subcategory added' : 'Price updated');
    _subcategoryController.clear();
    _priceController.clear();
    setState(() => _showAddForm = false);
  }

  Future<void> _showEditSubcategoryDialog(String oldName) async {
    final currentPrice =
        context
            .read<ServicesStore>()
            .serviceFor(category: _selectedCategory, subcategory: oldName)
            ?.price ??
        0.0;

    final result = await showServiceEditSheet(
      context: context,
      title: 'Edit Subcategory',
      nameLabel: 'Subcategory name',
      name: oldName,
      price: currentPrice,
    );
    if (result == null || !mounted) return;

    final store = context.read<ServicesStore>();
    final renamed = await store.renameSubcategory(
      category: _selectedCategory,
      oldName: oldName,
      newName: result.name,
    );
    if (!renamed) {
      ToastService.error('Unable to update. Name may already exist.');
      return;
    }
    await store.updatePriceForSubcategory(
      category: _selectedCategory,
      subcategory: result.name,
      price: result.price,
    );
    ToastService.success('Subcategory updated');
  }
}
