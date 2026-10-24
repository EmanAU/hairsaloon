import 'package:hairsaloon/src/features/settings/presentation/payment_accounts_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/core/widgets/made_with_love_credit.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/expenses/presentation/manage_expense_types_screen.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../online/data/business_workspace.dart';
import '../../../online/presentation/team_contracts_screen.dart';
import '../../../online/presentation/online_dashboard_tools.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static final Uri _intelligementUri = Uri.parse(
    'http://www.intelligement.com/',
  );

  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _iconBg = Color(0xFFF7F8F7);
  static const Color _iconColor = Color(0xFF4A6355);
  static const Color _headerBg = Color(0xFFCDFA4A);

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<BusinessWorkspace?>();
    final profile = context.watch<BusinessProfileNotifier>().profile;
    final businessName = (profile?.businessName.trim().isNotEmpty ?? false)
        ? profile!.businessName
        : 'Business';

    return Drawer(
      backgroundColor: AppColors.surface,
      surfaceTintColor: const Color(0x00000000),
      elevation: 0,
      width: (MediaQuery.sizeOf(context).width * .86).clamp(280.0, 340.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.zero,
          bottomRight: Radius.zero,
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
                  if (workspace != null) ...[
                    const _SectionLabel('TEAM'),
                    _Item(
                      icon: CupertinoIcons.doc_text,
                      title: 'Contracts',
                      showDivider: true,
                      onTap: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => TeamContractsScreen(
                              repository: workspace.repository,
                              businessId: workspace.business.id,
                              business: workspace.business,
                            ),
                          ),
                        );
                      },
                    ),
                    _Item(
                      icon: CupertinoIcons.envelope,
                      title: 'Invite replies',
                      showDivider: false,
                      onTap: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => OwnerInvitesScreen(
                              repository: workspace.repository,
                              businessId: workspace.business.id,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
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
                    icon: CupertinoIcons.chart_bar,
                    title: 'Sales History',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.pushNamed(AppRoutes.financeSales);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.chart_pie,
                    title: 'Finance Overview',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.pushNamed(AppRoutes.financeOverview);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.creditcard,
                    title: 'Payment Accounts',
                    showDivider: true,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const PaymentAccountsScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.tag,
                    title: 'Expense Types',
                    showDivider: true,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const ManageExpenseTypesScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.money_dollar_circle,
                    title: 'Currency Change',
                    showDivider: true,
                    onTap: () async {
                      final settings = context.read<SettingsStore>();
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      await _showCurrencyDialog(navigator.context, settings);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.percent,
                    title: 'Tax Rate',
                    showDivider: false,
                    trailing: const _TaxBadge(),
                    onTap: () async {
                      final settings = context.read<SettingsStore>();
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      await _showTaxRateDialog(navigator.context, settings);
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

  static Future<void> _showTaxRateDialog(
    BuildContext context,
    SettingsStore settingsStore,
  ) async {
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
    if (context.mounted) {
      ToastService.success('Tax rate saved', context);
    }
  }

  static Future<void> _showCurrencyDialog(
    BuildContext context,
    SettingsStore settingsStore,
  ) async {
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
      validator: (value) => value.length == 3 ? null : 'Enter a 3-letter code',
    );
    if (value == null) return;
    await settingsStore.setCurrencyCode(value.toUpperCase());
    if (context.mounted) {
      ToastService.success('Currency updated', context);
    }
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
        border: Border(bottom: BorderSide(color: AppDrawer._divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TrimMatrix',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                ),
              ),
              IconButton(
                tooltip: 'Close menu',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.xmark, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                CupertinoIcons.person_crop_circle,
                size: 38,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR BUSINESS',
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
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                backgroundColor: Colors.white,
                foregroundColor: AppColors.danger,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppDrawer._divider),
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
            borderRadius: BorderRadius.circular(4),
            splashColor: AppColors.primary.withValues(alpha: 0.12),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 24,
                    child: Icon(icon, size: 20, color: AppDrawer._iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
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
