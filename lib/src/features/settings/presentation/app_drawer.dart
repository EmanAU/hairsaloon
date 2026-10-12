import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Design tokens (mirrors registration screen) ──────────────────────────────
class _C {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F6F6);
  static const surfaceHigh = Color(0xFFECECEC);
  static const border = Color(0xFFE3E3E3);
  static const lime = Color(0xFFD4FF33);
  static const textPrimary = Color(0xFF0D0D0D);
  static const textSecondary = Color(0xFF6B6B6B);
  static const error = Color(0xFFFF5C5C);
}

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static final Uri _intelligementUri = Uri.parse(
    'http://www.intelligement.com/',
  );

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(),

            const SizedBox(height: 8),

            // ── Menu list ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  _SectionLabel('GENERAL'),
                  _Item(
                    icon: CupertinoIcons.person_crop_circle,
                    title: 'Profile Settings',
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
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.accountProfile);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.person_3,
                    title: 'Employees',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.employees);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.person_2,
                    title: 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.customers);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SectionLabel('CATALOGUE'),
                  _Item(
                    icon: CupertinoIcons.list_bullet_indent,
                    title: 'Categories',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.categories);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.money_dollar,
                    title: 'Rate List',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.serviceList);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SectionLabel('FINANCE'),
                  _Item(
                    icon: CupertinoIcons.creditcard,
                    title: 'Expense List',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(AppRoutes.expenses);
                    },
                  ),
                  _Item(
                    icon: CupertinoIcons.money_dollar_circle,
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
                    icon: CupertinoIcons.percent,
                    title: 'Tax Rate',
                    trailing: _TaxBadge(),
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

            // ── Bottom: version + logout ──────────────────────────────────
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon + name row
          Row(
            children: [
              const Text("  "),
              const SizedBox(width: 60),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saloon Management',
                    style: TextStyle(
                      color: _C.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logout button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _C.error.withValues(alpha: 0.08),
                foregroundColor: _C.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _C.error.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              onPressed: () => _handleLogout(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.square_arrow_left, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Made with ❤️ by ',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                InkWell(
                  onTap: _openIntelligementWebsite,
                  borderRadius: BorderRadius.circular(4),
                  child: const Text(
                    'Intelligement',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tax dialog ───────────────────────────────────────────────────────────
  Future<void> _showTaxRateDialog(BuildContext context) async {
    final settingsStore = context.read<SettingsStore>();
    final controller = TextEditingController(
      text: settingsStore.taxRate.toStringAsFixed(0),
    );
    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        const radius = 6.0;
        InputDecoration fieldDecoration() {
          return InputDecoration(
            hintText: 'Enter percentage e.g. 16',
            hintStyle: const TextStyle(color: Colors.black54),
            suffixText: '%',
            suffixStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
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
          backgroundColor: _C.lime,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          title: const Text(
            'Tax Rate',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
            decoration: fieldDecoration(),
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
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
    if (didSave != true) return;
    ToastService.success('Tax rate saved');
  }

  Future<void> _showCurrencyDialog(BuildContext context) async {
    final settingsStore = context.read<SettingsStore>();
    final current = settingsStore.currencyCode;
    final controller = TextEditingController(text: current);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Currency Change',
          style: TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: $current',
              style: const TextStyle(
                color: _C.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              style: const TextStyle(color: _C.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter new currency code (e.g. PKR)',
                hintStyle: const TextStyle(color: _C.textSecondary),
                filled: true,
                fillColor: _C.surface,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
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
              style: TextStyle(color: _C.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final next = controller.text.trim().toUpperCase();
              if (next.length != 3) {
                Navigator.of(dialogContext).pop(false);
                return;
              }
              await settingsStore.setCurrencyCode(next);
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (didSave != true) return;
    ToastService.success('Currency updated');
  }

  Future<void> _openIntelligementWebsite() async {
    await launchUrl(_intelligementUri, mode: LaunchMode.externalApplication);
  }

  // ─── Logout ───────────────────────────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final authStore = context.read<AuthStore>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _C.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    // Close drawer first, then clear session and reset navigation stack.
    navigator.pop();
    await authStore.logout();
    if (!mounted) return;

    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: _C.lime.withValues(alpha: 0.06),
          highlightColor: _C.lime.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _C.border, width: 1),
                  ),
                  child: Icon(icon, size: 17, color: _C.textSecondary),
                ),
                const SizedBox(width: 13),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                // Trailing or chevron
                trailing ??
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 13,
                      color: _C.textSecondary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tax badge ─────────────────────────────────────────────────────────────────

class _TaxBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final taxRate = context.select<SettingsStore, double>(
      (store) => store.taxRate,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _C.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Text(
        '${taxRate.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
