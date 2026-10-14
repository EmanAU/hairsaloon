import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hairsaloon/src/core/widgets/made_with_love_credit.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_format.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late DateTime _today;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    _today = FinanceCalculator.dayOf(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _dayTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDay(),
    );
  }

  void _refreshDay() {
    final day = FinanceCalculator.dayOf(DateTime.now());
    if (day != _today) setState(() => _today = day);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<BusinessProfileNotifier>().profile;
    final name = profile?.businessName.trim() ?? '';
    final address = profile?.address.trim() ?? '';
    final location = address.isNotEmpty
        ? address
        : [
            profile?.area.trim(),
            profile?.city.trim(),
          ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final totals = FinanceCalculator.totals(
      bills: context.watch<BillingStore>().bills,
      expenses: context.watch<ExpensesStore>().items,
      payouts: context.watch<PayoutsStore>().payouts,
      anchor: _today,
      period: FinancePeriod.daily,
    );
    final team = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .length;
    final currency = context.watch<SettingsStore>().currencyCode;
    String amount(double value) => value
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    void open(String route) => Navigator.of(context).pushNamed(route);
    void finance(String route) => Navigator.of(context).pushNamed(
      route,
      arguments: FinanceRouteArgs(anchor: _today, period: FinancePeriod.daily),
    );

    return ColoredBox(
      color: AppColors.homeCanvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 600;
          final bottomPad = MediaQuery.paddingOf(context).bottom;
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 72 + bottomPad),
            children: [
              _BusinessHeader(
                name: name.isEmpty ? 'Your business' : name,
                location: location,
                date: FinanceFormat.date(_today),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 24 : 16,
                      12,
                      tablet ? 24 : 16,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Today at a glance',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.homeInk,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => open(AppRoutes.financeOverview),
                              child: const Text(
                                'View finance',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.homeInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.homeBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _Stat(
                                label: "Today's sales",
                                value: amount(totals.sales),
                                currency: currency,
                                subtitle:
                                    '${totals.billCount} ${totals.billCount == 1 ? 'bill' : 'bills'} created',
                                prominent: true,
                                onTap: () => finance(AppRoutes.financeSales),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.homeBorder,
                              ),
                              IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _Stat(
                                        label: 'Net profit',
                                        value: amount(totals.profit),
                                        currency: currency,
                                        onTap: () =>
                                            finance(AppRoutes.financeProfit),
                                      ),
                                    ),
                                    const VerticalDivider(
                                      width: 1,
                                      color: AppColors.homeBorder,
                                    ),
                                    Expanded(
                                      child: _Stat(
                                        label: 'Expenses',
                                        value: amount(totals.expenses),
                                        currency: currency,
                                        onTap: () =>
                                            finance(AppRoutes.financeExpenses),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Manage business',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.homeInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 92,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _Shortcut(
                              title: 'Employees',
                              detail: '$team active',
                              icon: CupertinoIcons.person_2,
                              tint: AppColors.homeSage,
                              accent: AppColors.homeOlive,
                              onTap: () => open(AppRoutes.employees),
                            ),
                            _Shortcut(
                              title: 'Rate List',
                              detail: 'Services & prices',
                              icon: CupertinoIcons.scissors,
                              tint: AppColors.homePeach,
                              accent: AppColors.homeTerracotta,
                              onTap: () => open(AppRoutes.serviceList),
                            ),
                            _Shortcut(
                              title: 'Customers',
                              detail: 'Visits & history',
                              icon: CupertinoIcons.person_crop_rectangle,
                              tint: AppColors.homeLavender,
                              accent: AppColors.homePlum,
                              onTap: () => open(AppRoutes.customers),
                            ),
                            _Shortcut(
                              title: 'Finance',
                              detail: 'Income & expenses',
                              icon: CupertinoIcons.chart_bar,
                              tint: AppColors.homeSand,
                              accent: AppColors.homeBronze,
                              onTap: () => open(AppRoutes.financeOverview),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: MadeWithLoveCredit(
                            fontSize: 9.5,
                            onTap: () async => launchUrl(
                              Uri.parse('http://www.intelligement.com/'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({
    required this.name,
    required this.location,
    required this.date,
  });
  final String name;
  final String location;
  final String date;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _HeaderCurve(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/home_salon.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.5, 0.1),
              cacheWidth: 1200,
              errorBuilder: (_, error, stack) =>
                  const ColoredBox(color: AppColors.homeInk),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Open menu',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              minimumSize: const Size(40, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              CupertinoIcons.bars,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          color: Color(0xFFE4D8C7),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE4D8C7),
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCurve extends CustomClipper<Path> {
  const _HeaderCurve();
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 18)
    ..quadraticBezierTo(
      size.width * 0.28,
      size.height + 10,
      size.width * 0.65,
      size.height - 8,
    )
    ..quadraticBezierTo(
      size.width * 0.88,
      size.height - 20,
      size.width,
      size.height - 10,
    )
    ..lineTo(size.width, 0)
    ..close();
  @override
  bool shouldReclip(_HeaderCurve oldClipper) => false;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.currency,
    required this.onTap,
    this.subtitle,
    this.prominent = false,
  });
  final String label;
  final String value;
  final String currency;
  final String? subtitle;
  final bool prominent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            prominent ? 14 : 12,
            prominent ? 12 : 10,
            prominent ? 14 : 12,
            prominent ? 12 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (prominent)
                    const Icon(
                      CupertinoIcons.arrow_up_right,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currency,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: prominent ? 22 : 16,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.homeInk,
                    ),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.title,
    required this.detail,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });
  final String title;
  final String detail;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.homeInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
