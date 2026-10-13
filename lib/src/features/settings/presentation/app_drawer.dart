import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static final Uri _intelligementUri = Uri.parse(
    'http://www.intelligement.com/',
  );

  static const Color _divider = Color(0xFFE3E3E3);

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<BusinessProfileNotifier>().profile;
    final businessName = (profile?.businessName.trim().isNotEmpty ?? false)
        ? profile!.businessName
        : 'Business';

    return Drawer(
      backgroundColor: AppColors.surface,
      surfaceTintColor: const Color(0x00000000),
      elevation: 0,
      width: 288,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(businessName: businessName),
            const Divider(height: 1, thickness: 1, color: _divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  const _SectionLabel('GENERAL'),
                  _Item(
                    title: 'Profile Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.profileSettings);
                    },
                  ),
                  _Item(
                    title: 'Account',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.accountProfile);
                    },
                  ),
                  _Item(
                    title: 'Employees',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.employees);
                    },
                  ),
                  _Item(
                    title: 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.customers);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  const _SectionLabel('CATALOGUE'),
                  _Item(
                    title: 'Categories',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.categories);
                    },
                  ),
                  _Item(
                    title: 'Rate List',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.serviceList);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  const _SectionLabel('FINANCE'),
                  _Item(
                    title: 'Expense List',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.expenses);
                    },
                  ),
                  _Item(
                    title: 'Currency Change',
                    onTap: () async {
                      final rootNavigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      Navigator.pop(context);
                      await _showCurrencyDialog(rootNavigator.context);
                    },
                  ),
                  _Item(
                    title: 'Tax Rate',
                    trailing: const _TaxBadge(),
                    onTap: () async {
                      final rootNavigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      Navigator.pop(context);
                      await _showTaxRateDialog(rootNavigator.context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _divider),
            _Footer(
              onLogout: () => _handleLogout(context),
              onOpenSite: _openIntelligementWebsite,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showTaxRateDialog(BuildContext context) async {
    final settingsStore = context.read<SettingsStore>();
    final controller = TextEditingController(
      text: settingsStore.taxRate.toStringAsFixed(0),
    );
    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        const radius = 8.0;
        return AlertDialog(
          backgroundColor: AppColors.primary,
          surfaceTintColor: const Color(0x00000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          title: const Text(
            'Tax Rate',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter percentage e.g. 16',
              hintStyle: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              suffixText: '%',
              suffixStyle: const TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppColors.onPrimary),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.onPrimary,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  Navigator.of(dialogContext).pop(false);
                  return;
                }
                settingsStore.setTaxRate(value);
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (didSave != true) return;
    ToastService.success('Tax rate saved');
  }

  static Future<void> _showCurrencyDialog(BuildContext context) async {
    final settingsStore = context.read<SettingsStore>();
    final current = settingsStore.currencyCode;
    final controller = TextEditingController(text: current);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Currency Change',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: $current',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. PKR',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surface,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _divider),
                ),
              ),
            ),
          ],
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () async {
              final next = controller.text.trim().toUpperCase();
              if (next.length != 3) {
                Navigator.of(dialogContext).pop(false);
                return;
              }
              await settingsStore.setCurrencyCode(next);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (didSave != true) return;
    ToastService.success('Currency updated');
  }

  static Future<void> _openIntelligementWebsite() async {
    await launchUrl(_intelligementUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final authStore = context.read<AuthStore>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Logout',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    navigator.pop();
    await authStore.logout();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.businessName});

  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Text(
        businessName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.25,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onLogout, required this.onOpenSite});

  final VoidCallback onLogout;
  final VoidCallback onOpenSite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                foregroundColor: AppColors.danger,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
              ),
              onPressed: onLogout,
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Made with care by ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: onOpenSite,
                borderRadius: BorderRadius.circular(4),
                child: const Text(
                  'Intelligement',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      minVerticalPadding: 10,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _TaxBadge extends StatelessWidget {
  const _TaxBadge();

  @override
  Widget build(BuildContext context) {
    final taxRate = context.select<SettingsStore, double>(
      (store) => store.taxRate,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppDrawer._divider),
      ),
      child: Text(
        '${taxRate.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
