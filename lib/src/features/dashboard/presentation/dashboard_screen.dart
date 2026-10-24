import '../../../online/data/business_workspace.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hairsaloon/src/core/widgets/made_with_love_credit.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/finance_widgets.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/services/presentation/categories_screen.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.extraShortcuts, this.onOpenRateList});
  final Widget? extraShortcuts;

  /// When set (hosted online), Rate List opens the customer catalogue.
  final VoidCallback? onOpenRateList;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  DateTime _today = FinanceCalculator.dayOf(DateTime.now());
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _refresh() {
    final today = FinanceCalculator.dayOf(DateTime.now());
    if (today != _today) setState(() => _today = today);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onlineWorkspace = context.watch<BusinessWorkspace?>();
    final compactHome = onlineWorkspace != null;
    final profile = context.watch<BusinessProfileNotifier>().profile;
    final owner = context.watch<AuthStore>().currentUser?.name.trim() ?? '';
    final business = profile?.businessName.trim() ?? '';
    final address = profile?.address.trim() ?? '';
    final billing = context.watch<BillingStore>();
    final team = context
        .watch<EmployeesStore>()
        .employees
        .where((e) => e.isActive)
        .length;
    final customers = billing.bills
        .map((b) {
          final name = b.customerName.trim();
          final phone = b.customerPhone.trim();
          return name.isNotEmpty
              ? (phone.isEmpty ? name : '$name • $phone')
              : (phone.isEmpty ? 'Walk-in Customer' : phone);
        })
        .toSet()
        .length;
    final sales = billing.bills
        .where((b) => FinanceCalculator.dayOf(b.createdAt) == _today)
        .fold<double>(0, (sum, b) => sum + b.grandTotal);
    final currency = context.watch<SettingsStore>().currencyCode;
    final money = sales
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    void open(String route) => Navigator.of(context).pushNamed(route);
    return ColoredBox(
      color: const Color(0xFFF6F7F9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 600;
          return ListView(
            padding: EdgeInsets.only(
              bottom: 82 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Header(
                owner: owner.isEmpty ? 'Welcome' : owner,
                business: business.isEmpty ? 'Your business' : business,
                address: address,
                logo: profile?.logoBase64,
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: tablet ? 24 : 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        if (!compactHome)
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStat(
                                  label: 'Employees',
                                  value: '$team',
                                  asset: 'employees',
                                  tint: const Color(0xFFE9FBE4),
                                  onTap: () => open(AppRoutes.employees),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Customers',
                                  value: '$customers',
                                  asset: 'customers',
                                  tint: const Color(0xFFEBF1FF),
                                  onTap: () => open(AppRoutes.customers),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Sales today',
                                  value: '$currency $money',
                                  asset: 'rates',
                                  tint: const Color(0xFFFFF5D9),
                                  onTap: () => Navigator.of(context).pushNamed(
                                    AppRoutes.financeSales,
                                    arguments: FinanceRouteArgs(
                                      anchor: _today,
                                      period: FinancePeriod.daily,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        GridView(
                          padding: widget.extraShortcuts == null
                              ? null
                              : EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: tablet ? 144 : 118,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            if (!compactHome)
                              DashboardShortcut(
                                title: 'Employees',
                                detail: 'Manage your team\nmembers and roles.',
                                asset: 'employees',
                                tint: const Color(0xFFF0FBDD),
                                onTap: () => open(AppRoutes.employees),
                              ),
                            DashboardShortcut(
                              title: 'Rate List',
                              detail: 'View services\nand pricing.',
                              asset: 'rates',
                              tint: const Color(0xFFFFF4DB),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const CategoriesScreen(readOnly: true),
                                  ),
                                );
                              },
                            ),
                            if (!compactHome)
                              DashboardShortcut(
                                title: 'Customers',
                                detail: 'Manage customer\ndetails and records.',
                                asset: 'customers',
                                tint: const Color(0xFFEAF0FF),
                                onTap: () => open(AppRoutes.customers),
                              ),
                            DashboardShortcut(
                              title: 'Finance',
                              detail:
                                  'Track income, expenses\nand financial reports.',
                              asset: 'finance',
                              tint: const Color(0xFFE1FBEC),
                              onTap: () => open(AppRoutes.financeOverview),
                            ),
                          ],
                        ),
                        if (widget.extraShortcuts != null) ...[
                          const SizedBox(height: 12),
                          widget.extraShortcuts!,
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.border),
                            ),
                            const SizedBox(width: 12),
                            MadeWithLoveCredit(
                              fontSize: 9,
                              onTap: () async => launchUrl(
                                Uri.parse('http://www.intelligement.com/'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Divider(color: AppColors.border),
                            ),
                          ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.owner,
    required this.business,
    required this.address,
    this.logo,
  });
  final String owner, business, address;
  final String? logo;
  @override
  Widget build(BuildContext context) {
    ImageProvider? avatar;
    if (logo?.isNotEmpty ?? false) {
      try {
        avatar = MemoryImage(base64Decode(logo!));
      } on FormatException {
        avatar = null;
      }
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5FF97), Color(0xFFCAFC58), Color(0xFFB8F73E)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -65,
              child: Container(
                width: 260,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: 28,
              child: Opacity(
                opacity: 0.65,
                child: Image.asset(
                  'assets/home_shop.png',
                  width: 165,
                  height: 165,
                  cacheWidth: 400,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Open menu',
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.3,
                                ),
                                elevation: 3,
                                shadowColor: Colors.black12,
                                minimumSize: const Size(44, 44),
                              ),
                              icon: const Icon(
                                CupertinoIcons.bars,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Business profile',
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.profileSettings),
                              icon: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child: avatar == null
                                    ? const Icon(
                                        CupertinoIcons.person_fill,
                                        color: AppColors.homeInk,
                                        size: 23,
                                      )
                                    : ClipOval(
                                        child: Image(
                                          image: avatar,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, error, stack) =>
                                              const Icon(
                                                CupertinoIcons.person_fill,
                                              ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'WELCOME BACK',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF485929),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(right: 65),
                          child: Text(
                            owner,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                              letterSpacing: -0.7,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.location_solid,
                                  size: 11,
                                  color: AppColors.homeInk,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _Identity(
                                    label: 'Business Name',
                                    value: business,
                                    icon: CupertinoIcons.bag_fill,
                                  ),
                                ),
                                const VerticalDivider(
                                  width: 16,
                                  color: Color(0xFFD7E9B6),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: _Identity(
                                    label: 'Signed in as',
                                    value: owner,
                                    icon: CupertinoIcons.person_fill,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _Identity extends StatelessWidget {
  const _Identity({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFDDFBB7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF4B8C1F)),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.asset,
    required this.tint,
    required this.onTap,
  });
  final String label, value, asset;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 30,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset('assets/home_$asset.png', cacheWidth: 100),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    super.key,
    required this.title,
    required this.detail,
    required this.asset,
    required this.tint,
    required this.onTap,
    this.badge,
  });
  final String title, detail, asset;
  final Color tint;
  final VoidCallback onTap;
  final int? badge;
  Widget _image() => Image.asset(
    'assets/home_$asset.png',
    width: 36,
    height: 36,
    cacheWidth: 240,
  );
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x090F172A),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CardWash(tint))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: badge == null
                                ? _image()
                                : Badge(
                                    label: Text('$badge'),
                                    isLabelVisible: badge! > 0,
                                    child: _image(),
                                  ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 12,
                            color: AppColors.homeInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.25,
                      color: Color(0xFF7B8194),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardWash extends CustomPainter {
  const _CardWash(this.tint);
  final Color tint;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 12)
      ..lineTo(size.width * .48, 12)
      ..cubicTo(
        size.width * .65,
        12,
        size.width * .38,
        size.height * .4,
        size.width * .8,
        size.height * .52,
      )
      ..quadraticBezierTo(size.width, size.height * .6, size.width, size.height)
      ..lineTo(12, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, tint.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CardWash oldDelegate) => tint != oldDelegate.tint;
}
