import 'package:flutter/cupertino.dart';
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
                    icon: CupertinoIcons.briefcase,
                    title: 'Managers',
                    showDivider: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.managers);
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
                    title: 'Categories',
                    showDivider: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.categories);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.money_dollar,
                    title: 'Rate List',
                    showDivider: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.serviceList);
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
    final controller = TextEditingController(text: current);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SafeArea(
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: const Color(0x00000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Tax Rate',
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
                'Current: $current%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 16',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: _headerBg,
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
        ),
      ),
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
      builder: (dialogContext) => SafeArea(
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                  fillColor: _headerBg,
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
      builder: (dialogContext) => SafeArea(
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Made with care by ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
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
                    fontSize: 10.5,
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
