import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final Uri _intelligementUri = Uri.parse(
    'http://www.intelligement.com/',
  );

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<BusinessProfileNotifier>().profile;
    final businessName = (profile?.businessName.trim().isNotEmpty ?? false)
        ? profile!.businessName
        : 'Sarfaraz Hair Salon';
    final address = (profile?.address.trim().isNotEmpty ?? false)
        ? profile!.address
        : (profile != null && profile.area.trim().isNotEmpty)
        ? '${profile.area}, ${profile.city}'
        : 'G-11 Markaz, Islamabad';

    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = shortest >= 600
        ? (width >= 1000 ? 4 : 3)
        : 2;

    return ListView(
      padding: EdgeInsets.only(bottom: 100.h),
      children: [
        // ── Header (drawer icon original top-left) ────────────────────────
        Container(
          color: AppColors.primary,
          // Slightly smaller than original (16/28 → 14/22)
          padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 22.h),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        CupertinoIcons.bars,
                        color: AppColors.onPrimary,
                        size: 20.r,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.5),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  businessName,
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location_solid,
                      size: 11.r,
                      color: AppColors.onPrimary.withValues(alpha: 0.45),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onPrimary.withValues(alpha: 0.5),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Grid ──────────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 8.h),
          child: GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: 1.28,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DashboardTile(
                label: 'Employees',
                assetPath: 'assets/employees.png',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.employees),
              ),
              _DashboardTile(
                label: 'Rate List',
                assetPath: 'assets/ratelust.png',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.serviceList),
              ),
              _DashboardTile(
                label: 'Customers',
                assetPath: 'assets/customers.png',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.customers),
              ),
              _DashboardTile(
                label: 'Finance',
                assetPath: 'assets/finance.png',
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.financeOverview),
              ),
            ],
          ),
        ),

        // ── Credit below cards ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Made with care by ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: _openIntelligementWebsite,
                borderRadius: BorderRadius.circular(4.r),
                child: Text(
                  'Intelligement',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openIntelligementWebsite() async {
    await launchUrl(_intelligementUri, mode: LaunchMode.externalApplication);
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = 12.r;
    final tileSurface = Theme.of(context).colorScheme.surface;

    return Material(
      color: tileSurface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 10.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: Image.asset(assetPath, fit: BoxFit.contain),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                    height: 1.1,
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
