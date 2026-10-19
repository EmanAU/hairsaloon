import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/layout/safe_scroll_padding.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategories_screen.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.readOnly = false});

  /// Home Rate List: same layout as Manage Rate List, without add/edit.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServicesStore>();
    final categories = store.categories;
    final titlePrefix = readOnly ? 'Rate List' : 'Manage Rate List';

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
          '$titlePrefix (${categories.length.toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!readOnly)
            IconButton(
              tooltip: 'Add category',
              onPressed: () => _showAddOrEditCategory(context),
              icon: const Icon(CupertinoIcons.add, color: AppColors.onPrimary),
            ),
        ],
      ),
      body: categories.isEmpty
          ? Center(
              child: Text(
                readOnly
                    ? 'No categories yet.'
                    : 'No categories yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                          builder: (_) => SubcategoriesScreen(
                            initialCategory: category,
                            readOnly: readOnly,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        12,
                        readOnly ? 12 : 6,
                        12,
                      ),
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
                          if (!readOnly)
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
                          if (!readOnly) const SizedBox(width: 6),
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
    final name = await showAppTextInputSheet(
      context: context,
      title: isEdit ? 'Rename Category' : 'Add Category',
      subtitle: isEdit ? 'Current: $existing' : 'Group related services.',
      icon: CupertinoIcons.square_grid_2x2,
      label: 'Category name',
      hint: 'e.g. Hair Care',
      initialValue: existing ?? '',
      confirmLabel: isEdit ? 'Update' : 'Add',
      textCapitalization: TextCapitalization.words,
      validator: (value) => value.isEmpty ? 'Enter a category name' : null,
    );
    if (name == null || !context.mounted) return;

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
