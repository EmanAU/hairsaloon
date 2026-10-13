import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategories_screen.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServicesStore>();
    final categories = store.categories;

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
          'Categories (${categories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _showAddOrEditCategory(context),
            icon: const Icon(CupertinoIcons.add, color: AppColors.onPrimary),
          ),
        ],
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'No categories yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          : ListView.separated(
              padding: SafeScrollPadding.of(
                context,
                left: 12,
                top: 14,
                right: 12,
                bottom: 24,
              ),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final subCount = store.subcategoriesFor(category).length;
                return Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE1E1E1)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubcategoriesScreen(initialCategory: category),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$subCount subcategor${subCount == 1 ? 'y' : 'ies'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _showAddOrEditCategory(
                                  context,
                                  existing: category,
                                );
                                return;
                              }
                              if (value == 'delete') {
                                final store = context.read<ServicesStore>();
                                final confirm = await showAppConfirmDialog(
                                  context: context,
                                  title: 'Delete Category',
                                  message:
                                      'Delete "$category"? All its subcategories and services will be removed.',
                                  confirmLabel: 'Delete',
                                  isDestructive: true,
                                );
                                if (confirm != true) return;
                                await store.deleteCategory(category);
                                ToastService.success('Category deleted');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            icon: const Icon(
                              CupertinoIcons.ellipsis_vertical,
                              size: 18,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddOrEditCategory(
    BuildContext context, {
    String? existing,
  }) async {
    final isEdit = existing != null;
    final controller = TextEditingController(text: existing ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return SafeArea(
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: const Color(0x00000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              isEdit ? 'Rename Category' : 'Add Category',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Hair Care',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  isEdit ? 'Update' : 'Add',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !context.mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) {
      ToastService.error('Enter a category name');
      return;
    }

    final store = context.read<ServicesStore>();
    if (isEdit) {
      final ok = await store.renameCategory(oldName: existing, newName: name);
      ToastService.success(ok ? 'Category updated' : 'Name already exists');
      return;
    }

    final ok = await store.addCategory(name);
    ToastService.success(ok ? 'Category added' : 'Category already exists');
  }
}
