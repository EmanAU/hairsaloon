import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategory_services_screen.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showAddForm = false;
  String _selectedCategoryTab = 'All';

  String? _newCategory;
  String? _newSubcategory;
  String? _newGender;
  String? _newAgeGroup;
  String _newPrice = '';
  final TextEditingController _newServiceNameCtrl = TextEditingController();

  List<String> get _categories => [
    'All',
    ...context.watch<ServicesStore>().categories,
  ];

  List<String> get _visibleCategories {
    if (_selectedCategoryTab == 'All') {
      return context.watch<ServicesStore>().categories;
    }
    return <String>[_selectedCategoryTab];
  }

  @override
  void dispose() {
    _newServiceNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ServicesStore>().categories;
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
          'Rate List (${categories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategoryTab;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  selectedColor: Colors.white,
                  backgroundColor: const Color(0xFFF8F8F8),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedCategoryTab = category;
                    });
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: _categories.length,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              children: [
                if (_showAddForm) ...[
                  _buildAddFormCard(context),
                  const SizedBox(height: 14),
                ],
                ..._visibleCategories.map(
                  (category) => _CategoryTile(
                    category: category,
                    subcategoryCount: context
                        .watch<ServicesStore>()
                        .subcategoriesFor(category)
                        .length,
                    onTap: () => _openCategoryRates(category),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFormCard(BuildContext context) {
    final store = context.watch<ServicesStore>();
    final availableSubcategories = _newCategory == null
        ? const <String>[]
        : store.subcategoriesFor(_newCategory!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Service',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              initialValue: _newCategory,
              decoration: _fieldDecoration('Select Category'),
              items: _categories
                  .where((e) => e != 'All')
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final nextCategory = value;
                setState(() {
                  _newCategory = nextCategory;
                  // User will pick subcategory manually.
                  _newSubcategory = null;
                  _newServiceNameCtrl.clear();
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select category.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _newServiceNameCtrl,
              decoration: _fieldDecoration('Service Name (optional)'),
              onChanged: (_) => setState(() {}),
              validator: (_) {
                final typed = _newServiceNameCtrl.text.trim();
                if (typed.isNotEmpty) return null;
                if (_newSubcategory == null ||
                    _newSubcategory!.trim().isEmpty) {
                  return 'Please select subcategory or enter service name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              initialValue: _newSubcategory,
              decoration: _fieldDecoration('Select Subcategory'),
              items: availableSubcategories
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: availableSubcategories.isEmpty
                  ? null
                  : (value) {
                      _newServiceNameCtrl.clear();
                      setState(() => _newSubcategory = value);
                    },
              validator: (value) {
                final typed = _newServiceNameCtrl.text.trim();
                if (typed.isNotEmpty) return null;
                if (value == null || value.trim().isEmpty)
                  return 'Please select subcategory.';
                return null;
              },
            ),
            if (_newCategory != null && availableSubcategories.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'No subcategory found. Please add from Subcategories screen.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              initialValue: _newGender,
              decoration: _fieldDecoration('Select Gender'),
              items: const ['Male', 'Female', 'Other']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _newGender = value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select gender.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              initialValue: _newAgeGroup,
              decoration: _fieldDecoration('Select Age Group'),
              items: const ['Adult', 'Child']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _newAgeGroup = value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select age group.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: _fieldDecoration('Enter Price'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _newPrice = value.trim(),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Please enter valid price.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
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
                onPressed: _saveService,
                child: const Text(
                  'Save Service',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
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

  Future<void> _saveService() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;
    if (_newCategory == null || _newGender == null || _newAgeGroup == null) {
      return;
    }

    final typedName = _newServiceNameCtrl.text.trim();
    final finalSubcategory = typedName.isNotEmpty
        ? typedName
        : (_newSubcategory ?? '').trim();
    if (finalSubcategory.isEmpty) return;

    if (typedName.isNotEmpty) {
      await context.read<ServicesStore>().addSubcategory(
        category: _newCategory!,
        subcategory: typedName,
      );
    }

    await context.read<ServicesStore>().addService(
      ServiceItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: _newCategory!,
        subcategory: finalSubcategory,
        gender: _newGender!,
        ageGroup: _newAgeGroup!,
        price: double.parse(_newPrice),
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectedCategoryTab = _newCategory!;
      _showAddForm = false;
      _newCategory = null;
      _newSubcategory = null;
      _newGender = null;
      _newAgeGroup = null;
      _newPrice = '';
      _newServiceNameCtrl.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _openCategoryRates(String category) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _CategoryRatesScreen(category: category),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.subcategoryCount,
    required this.onTap,
  });

  final String category;
  final int subcategoryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$subcategoryCount subcategories',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRatesScreen extends StatefulWidget {
  const _CategoryRatesScreen({required this.category});

  final String category;

  @override
  State<_CategoryRatesScreen> createState() => _CategoryRatesScreenState();
}

class _CategoryRatesScreenState extends State<_CategoryRatesScreen> {
  @override
  void initState() {
    super.initState();
  }

  List<String> get _subcategories =>
      context.watch<ServicesStore>().subcategoriesFor(widget.category);

  @override
  Widget build(BuildContext context) {
    final subcategories = _subcategories;
    final store = context.watch<ServicesStore>();

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
          '${widget.category} (${subcategories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        itemCount: subcategories.length,
        itemBuilder: (context, index) {
          final subcategory = subcategories[index];
          final price =
              store
                  .serviceFor(
                    category: widget.category,
                    subcategory: subcategory,
                  )
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
                        category: widget.category,
                        subcategory: subcategory,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subcategory,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Text(
                        'Rs.${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showEditDialog(
                              oldSubcategory: subcategory,
                              currentPrice: price,
                            );
                            return;
                          }
                          if (value == 'delete') {
                            await context
                                .read<ServicesStore>()
                                .deleteSubcategory(
                                  category: widget.category,
                                  subcategory: subcategory,
                                );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        icon: const Icon(
                          CupertinoIcons.ellipsis_vertical,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog({
    required String oldSubcategory,
    required double currentPrice,
  }) async {
    final nameController = TextEditingController(text: oldSubcategory);
    final priceController = TextEditingController(
      text: currentPrice <= 0 ? '' : currentPrice.toStringAsFixed(0),
    );

    final result = await showDialog<bool>(
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

    if (result != true || !mounted) return;

    final newName = nameController.text.trim();
    final parsed = double.tryParse(priceController.text.trim());
    if (newName.isEmpty || parsed == null || parsed <= 0) {
      _showMessage('Enter valid service name and price.');
      return;
    }

    final renamed = await context.read<ServicesStore>().renameSubcategory(
      category: widget.category,
      oldName: oldSubcategory,
      newName: newName,
    );
    if (!renamed) {
      _showMessage('Unable to update. Name may already exist.');
      return;
    }

    await context.read<ServicesStore>().updatePriceForSubcategory(
      category: widget.category,
      subcategory: newName,
      price: parsed,
    );

    setState(() {});
    _showMessage('Service updated.');
  }

  void _showMessage(String message) {
    ToastService.info(message);
  }
}
