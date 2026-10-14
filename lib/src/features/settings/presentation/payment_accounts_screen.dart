import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class PaymentAccountsScreen extends StatelessWidget {
  const PaymentAccountsScreen({super.key});

  Future<void> _edit(BuildContext context, [String? previous]) async {
    final store = context.read<SettingsStore>();
    await showAppSheet<void>(
      context: context,
      builder: (_) => _AccountForm(store: store, previous: previous),
    );
  }

  Future<void> _delete(BuildContext context, String account) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete payment account?',
      message:
          'Remove "$account"? Existing bills keep their saved payment details.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: CupertinoIcons.trash,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<SettingsStore>().removePaymentAccount(account);
      ToastService.success('Payment account deleted');
    } catch (_) {
      ToastService.error('Could not delete payment account.');
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    String account,
    String action,
  ) async {
    if (action == 'edit') {
      await _edit(context, account);
      return;
    }
    if (action == 'delete') {
      await _delete(context, account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
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
          'Payment Accounts',
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
            constraints: BoxConstraints(maxWidth: tablet ? 560 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  'Add a method and account holder, for example EasyPaisa — Abdullah. Saved accounts appear when choosing a payment method.',
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
                    onPressed: () => _edit(context),
                    child: const Text(
                      'Add Payment Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (store.paymentAccounts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'No payment accounts yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...store.paymentAccounts.map(
                    (account) => _AccountCard(
                      account: account,
                      onMenu: (action) => _onMenu(context, account, action),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onMenu});

  final String account;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final parts = account.split(' — ');
    final method = parts.isNotEmpty ? parts.first.trim() : account;
    final holder = parts.length > 1
        ? parts.skip(1).join(' — ').trim()
        : '';

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.creditcard,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (holder.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    holder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(CupertinoIcons.pencil, size: 16),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.trash,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
            icon: const Icon(
              CupertinoIcons.ellipsis_vertical,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.store, this.previous});
  final SettingsStore store;
  final String? previous;
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _method = TextEditingController(
    text: widget.previous?.split(' — ').first ?? '',
  );
  late final _holder = TextEditingController(
    text: widget.previous?.split(' — ').skip(1).join(' — ') ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _method.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.savePaymentAccount(
        previous: widget.previous,
        method: _method.text,
        holder: _holder.text,
      );
      if (mounted) Navigator.pop(context);
      ToastService.success('Payment account saved');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError
              ? e.message.toString()
              : 'Could not save payment account.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetBody(
    title: widget.previous == null
        ? 'Add Payment Account'
        : 'Edit Payment Account',
    confirmLabel: _saving ? 'Saving…' : 'Save',
    onConfirm: _saving ? null : _save,
    child: Column(
      children: [
        TextField(
          controller: _method,
          textInputAction: TextInputAction.next,
          decoration: appSheetInputDecoration('Method name (e.g. EasyPaisa)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _holder,
          textCapitalization: TextCapitalization.words,
          decoration: appSheetInputDecoration('Account holder (e.g. Abdullah)'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    ),
  );
}
