import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hairsaloon/src/core/widgets/app_confirm_dialog.dart';
import 'package:hairsaloon/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/billing_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expenses_screen.dart';
import 'package:hairsaloon/src/features/settings/presentation/app_drawer.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  bool _isExitDialogOpen = false;

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_currentIndex) {
      0 => const DashboardScreen(),
      1 => const BillingScreen(),
      2 => const ExpensesScreen(),
      _ => const DashboardScreen(),
    };

    final tablet = AdaptivePage.isTablet(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        extendBody: !tablet,
        drawer: const AppDrawer(),
        body: tablet
            ? Row(
                children: [
                  _SideRail(currentIndex: _currentIndex, onTap: _onTap),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: tablet
            ? null
            : _BottomNav(currentIndex: _currentIndex, onTap: _onTap),
      ),
    );
  }

  void _handleBackPressed() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    _showExitDialog();
  }

  Future<void> _showExitDialog() async {
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;
    final shouldExit = await showAppConfirmDialog(
      context: context,
      title: 'Exit App',
      message: 'Are you sure you want to exit the app?',
      confirmLabel: 'Exit',
      icon: CupertinoIcons.power,
    );
    _isExitDialogOpen = false;
    if (shouldExit == true && mounted) {
      await SystemNavigator.pop();
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const _navItems = [
  _NavItem(
    icon: CupertinoIcons.house,
    activeIcon: CupertinoIcons.house_fill,
    label: 'Home',
  ),
  _NavItem(
    icon: CupertinoIcons.doc_plaintext,
    activeIcon: CupertinoIcons.doc_text_fill,
    label: 'Billing',
  ),
  _NavItem(
    icon: CupertinoIcons.money_dollar_circle,
    activeIcon: CupertinoIcons.money_dollar_circle_fill,
    label: 'Expense',
  ),
];

class _SideRail extends StatelessWidget {
  const _SideRail({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        labelType: NavigationRailLabelType.all,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.textPrimary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minWidth: 84,
        groupAlignment: -0.85,
        selectedIconTheme: const IconThemeData(
          color: AppColors.surface,
          size: 21,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.iconMuted,
          size: 21,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: AppColors.iconMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                CupertinoIcons.line_horizontal_3,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        destinations: [
          for (final item in _navItems)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? bottomInset : 14),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _navItems.length; i++)
              Expanded(
                child: Tooltip(
                  message: _navItems[i].label,
                  child: Semantics(
                    button: true,
                    selected: i == currentIndex,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: _NavTile(
                        item: _navItems[i],
                        isActive: i == currentIndex,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.isActive});

  final _NavItem item;
  final bool isActive;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.surface : AppColors.iconMuted;
    return Center(
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        height: 42,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.textPrimary : const Color(0x00000000),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? item.activeIcon : item.icon, size: 20, color: color),
            AnimatedSize(
              duration: _duration,
              curve: Curves.easeOutCubic,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
