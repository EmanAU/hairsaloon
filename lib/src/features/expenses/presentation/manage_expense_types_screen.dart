import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class ManageExpenseTypesScreen extends StatelessWidget {
  const ManageExpenseTypesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final store = context.read<SettingsStore>();
    await showAppSheet<void>(
      context: context,
      builder: (_) => _AddExpenseTypeSheet(store: store),
    );
  }

  Future<void> _delete(BuildContext context, String type) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove expense type?',
      message: 'Remove "$type" from your list?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Remove',
      isDestructive: true,
      icon: CupertinoIcons.trash,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<SettingsStore>().removeExpenseType(type);
      ToastService.success('Expense type removed');
    } catch (e) {
      ToastService.error(
        e is ArgumentError
            ? e.message.toString()
            : 'Could not remove expense type.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final custom = store.customExpenseTypes;
    final defaults = SettingsStore.defaultExpenseTypes;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: AppColors.onPrimary),
        ),
        title: const Text(
          'Expense Types',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: tablet ? 560 : double.infinity,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  'Add custom expense types for your business. Defaults stay available on Add Expense.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _add(context),
                    child: const Text(
                      'Add Expense Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your types',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (custom.isEmpty)
                  _emptyCard('No custom types yet. Tap Add Expense Type.')
                else
                  ...custom.map(
                    (type) => _TypeCard(
                      label: type,
                      canDelete: true,
                      onDelete: () => _delete(context, type),
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Default types',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...defaults.map(
                  (type) => _TypeCard(label: type, canDelete: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.label,
    required this.canDelete,
    this.onDelete,
  });

  final String label;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(
                CupertinoIcons.trash,
                size: 18,
                color: AppColors.danger,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddExpenseTypeSheet extends StatefulWidget {
  const _AddExpenseTypeSheet({required this.store});
  final SettingsStore store;

  @override
  State<_AddExpenseTypeSheet> createState() => _AddExpenseTypeSheetState();
}

class _AddExpenseTypeSheetState extends State<_AddExpenseTypeSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.addExpenseType(_ctrl.text);
      if (mounted) Navigator.pop(context);
      ToastService.success('Expense type added');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError
              ? e.message.toString()
              : 'Could not add expense type.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Add Expense Type',
      confirmLabel: _saving ? 'Saving…' : 'Save',
      onConfirm: _saving ? null : _save,
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: appSheetInputDecoration(
              'Type name (e.g. Aesthetic Products)',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
