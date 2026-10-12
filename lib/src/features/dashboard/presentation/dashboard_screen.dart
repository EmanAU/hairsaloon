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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menu icon
                Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        CupertinoIcons.bars,
                        color: Colors.black,
                        size: 20.r,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                // Welcome label
                Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 5.h),
                // Business name
                Text(
                  businessName,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 6.h),
                // Address row
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location_solid,
                      size: 12.r,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      address,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
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
          padding: EdgeInsets.fromLTRB(18.w, 28.h, 18.w, 14.h),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14.w,
                mainAxisSpacing: 14.h,
                childAspectRatio: 1.18,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _DashboardTile(
                    label: 'Finance',
                    assetPath: 'assets/finance.png',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.financeOverview),
                  ),
                ],
              ),

              Transform.translate(
                offset: Offset(0, -10.h),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Made with ❤️ by ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    InkWell(
                      onTap: () => _openIntelligementWebsite(),
                      borderRadius: BorderRadius.circular(4.r),
                      child: Text(
                        'Intelligement',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
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
    this.assetPath,
    required this.onTap,
  });

  final String label;
  final String? assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = 16.r;
    final tileSurface = Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tileSurface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16.r,
              spreadRadius: 0,
              offset: Offset(0, 4.h),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4.r,
              spreadRadius: 0,
              offset: Offset(0, 1.h),
            ),
          ],
        ),
        child: Material(
          color: tileSurface,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.12),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 20.h, 14.w, 18.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.asset(assetPath!, fit: BoxFit.contain),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  // Label
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
