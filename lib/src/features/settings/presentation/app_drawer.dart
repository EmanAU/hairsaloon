import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/core/widgets/made_with_love_credit.dart';
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

  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _iconBg = Color(0xFFF7F8F4);
  static const Color _iconColor = Color(0xFF7A7A7A);
  static const Color _headerBg = Color(0xFFFBFCF7);

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
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(businessName: businessName),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                children: [
                  const _SectionLabel('GENERAL'),
                  _Item(
                    icon: CupertinoIcons.person_crop_circle,
                    title: 'Profile Settings',
                    showDivider: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.profileSettings);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.person_circle,
                    title: 'Account',
                    showDivider: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.accountProfile);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.person_3,
                    title: 'Employees',
                    showDivider: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.employees);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.person_2,
                    title: 'Customers',
                    showDivider: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.customers);
                    },
                  ),
                  const SizedBox(height: 10),
                  const _SectionLabel('CATALOGUE'),
                  _Item(
                    icon: CupertinoIcons.square_list,
                    title: 'Manage Rate List',
                    showDivider: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.categories);
                    },
                  ),
                  const SizedBox(height: 10),
                  const _SectionLabel('FINANCE'),
                  _Item(
                    icon: CupertinoIcons.money_dollar_circle,
                    title: 'Currency Change',
                    showDivider: true,
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
                    icon: CupertinoIcons.percent,
                    title: 'Tax Rate',
                    showDivider: false,
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
    final current = settingsStore.taxRate.toStringAsFixed(0);

    final value = await showAppTextInputSheet(
      context: context,
      title: 'Tax Rate',
      subtitle: 'Current: $current%. Applied to every new bill.',
      icon: CupertinoIcons.percent,
      label: 'Tax rate',
      hint: 'e.g. 16',
      initialValue: current,
      suffixText: '%',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        final parsed = double.tryParse(value);
        if (parsed == null || parsed < 0 || parsed > 100) {
          return 'Enter a value between 0 and 100';
        }
        return null;
      },
    );
    if (value == null) return;
    await settingsStore.setTaxRate(double.parse(value));
    ToastService.success('Tax rate saved');
  }

  static Future<void> _showCurrencyDialog(BuildContext context) async {
    final settingsStore = context.read<SettingsStore>();
    final current = settingsStore.currencyCode;

    final value = await showAppTextInputSheet(
      context: context,
      title: 'Currency',
      subtitle: 'Current: $current. Use a 3-letter code.',
      icon: CupertinoIcons.money_dollar_circle,
      label: 'Currency code',
      hint: 'e.g. PKR',
      initialValue: current,
      maxLength: 3,
      textCapitalization: TextCapitalization.characters,
      validator: (value) =>
          value.length == 3 ? null : 'Enter a 3-letter code',
    );
    if (value == null) return;
    await settingsStore.setCurrencyCode(value.toUpperCase());
    ToastService.success('Currency updated');
  }

  static Future<void> _openIntelligementWebsite() async {
    await launchUrl(_intelligementUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final authStore = context.read<AuthStore>();
    final shouldLogout = await showAppConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      isDestructive: true,
      icon: CupertinoIcons.square_arrow_right,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(
        color: AppDrawer._headerBg,
        border: Border(
          bottom: BorderSide(color: AppDrawer._divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              size: 20,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BUSINESS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.07),
                foregroundColor: AppColors.danger,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.18),
                  ),
                ),
              ),
              onPressed: onLogout,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.square_arrow_left, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          MadeWithLoveCredit(onTap: onOpenSite),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.05,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0x00000000),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.primary.withValues(alpha: 0.12),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppDrawer._iconBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDrawer._divider),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: AppDrawer._iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 6),
                  ],
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: Color(0xFFB0B0B0),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 54),
            child: Divider(height: 1, thickness: 1, color: AppDrawer._divider),
          ),
      ],
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
        color: AppDrawer._iconBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppDrawer._divider),
      ),
      child: Text(
        '${taxRate.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
