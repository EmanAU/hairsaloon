import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/pk_phone.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../online/data/business_workspace.dart';
import '../../../online/presentation/business_owner_details_screen.dart';
import '../../../online/presentation/invite_qr_screen.dart';
import '../../../online/presentation/join_requests_screen.dart';
import '../../router/app_routes.dart';
import '../../services/presentation/categories_screen.dart';

/// The approved bank-inspired home: yellow header, white canvas and four actions.
class BusinessDashboardHome extends StatelessWidget {
  const BusinessDashboardHome({
    super.key,
    required this.workspace,
    this.onGoOnline,
    this.onLogOut,
  });
  final BusinessWorkspace workspace;
  final VoidCallback? onGoOnline;
  final Future<void> Function()? onLogOut;
  static const yellow = Color(0xFFCDFA4A);
  static const green = Color(0xFF086744);
  static const ink = Color(0xFF202430);
  static const border = Color(0xFFECEDEF);

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final business = workspace.business;
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final horizontal = wide ? 28.0 : 20.0;
          return SingleChildScrollView(
            child: Stack(
              children: [
                Container(height: top + 220, color: yellow),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        top + 8,
                        horizontal,
                        32,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Open menu',
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                                icon: const _VectorIcon(
                                  'menu',
                                  color: ink,
                                  size: 22,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'TrimMatrix',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black,
                                            letterSpacing: -.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Log out',
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerRight,
                                onPressed: onLogOut == null
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showAppConfirmDialog(
                                              context: context,
                                              title: 'Log out?',
                                              message:
                                                  'Sign out of your TrimMatrix account?',
                                              confirmLabel: 'Log out',
                                              icon: CupertinoIcons
                                                  .square_arrow_right,
                                            );
                                        if (confirmed == true) {
                                          await onLogOut!();
                                        }
                                      },
                                icon: const _VectorIcon(
                                  'logout',
                                  color: ink,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 44),
                          Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                              side: const BorderSide(color: border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Business account',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF92969F),
                                              ),
                                            ),
                                          ),
                                          Tooltip(
                                            message: business.isActive
                                                ? 'Approved business'
                                                : 'Pending approval',
                                            child: Icon(
                                              CupertinoIcons.star,
                                              size: 18,
                                              color: const Color(0xFF92969F),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        business.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w400,
                                          color: green,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  workspace.account.name
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  PkPhone.localNumber(
                                                    business.phone,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  [business.area, business.city]
                                                      .where(
                                                        (s) =>
                                                            s.trim().isNotEmpty,
                                                      )
                                                      .join(', ')
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF92969F),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Tooltip(
                                            message: 'QR codes',
                                            child: Semantics(
                                              button: true,
                                              label: 'QR codes',
                                              child: InkWell(
                                                onTap: () => _open(
                                                  context,
                                                  InviteQrScreen(
                                                    repository:
                                                        workspace.repository,
                                                    businessId: business.id,
                                                  ),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: const SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: _VectorIcon(
                                                      'qr',
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: border,
                                ),
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _CardAction(
                                          label: 'Business Details',
                                          onTap: () => _open(
                                            context,
                                            BusinessOwnerDetailsScreen(
                                              workspace: workspace,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: border,
                                      ),
                                      Expanded(
                                        child: _CardAction(
                                          label: 'Go Online',
                                          onTap: onGoOnline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 17),
                          Container(
                            width: 19,
                            height: 3,
                            decoration: BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: wide ? 1.8 : 1.55,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            children: [
                              _HomeTile(
                                label: 'New Bill',
                                icon: 'bill',
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.billing),
                              ),
                              _HomeTile(
                                label: 'Rate List',
                                icon: 'list',
                                onTap: () => _open(
                                  context,
                                  const CategoriesScreen(readOnly: true),
                                ),
                              ),
                              _HomeTile(
                                label: 'Sales History',
                                icon: 'sales',
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.financeSales),
                              ),
                              _HomeTile(
                                label: 'Join Requests',
                                icon: 'join',
                                onTap: () => _open(
                                  context,
                                  JoinRequestsScreen(
                                    repository: workspace.repository,
                                    businessId: business.id,
                                    workspace: workspace,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: BusinessDashboardHome.ink,
      minimumSize: const Size(0, 48),
      shape: const RoundedRectangleBorder(),
      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
    child: Text(label),
  );
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label, icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: const BorderSide(color: BusinessDashboardHome.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _VectorIcon(icon),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: BusinessDashboardHome.ink,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VectorIcon extends StatelessWidget {
  const _VectorIcon(
    this.name, {
    this.color = BusinessDashboardHome.green,
    this.size = 27,
  });
  final String name;
  final Color color;
  final double size;
  static const paths = {
    'menu': '<path d="M3 6h18M3 12h18M3 18h18"/>',
    'logout':
        '<path d="M14 5V3a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v18a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-2M10 12h12M18 8l4 4-4 4"/>',
    'qr':
        '<g stroke-width="1.8"><rect x="2" y="2" width="7" height="7" rx=".5"/><rect x="15" y="2" width="7" height="7" rx=".5"/><rect x="2" y="15" width="7" height="7" rx=".5"/><path d="M5.5 5.5h.01M18.5 5.5h.01M5.5 18.5h.01M15 13h3v4h4v5h-4M13 17v5M22 12v2M13 12v1"/></g>',
    'bill':
        '<path d="M14 21H5a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9M7 6h8M7 10h6M7 14h3"/><circle cx="18" cy="18" r="5"/><path d="M18 15v6M15 18h6"/>',
    'list':
        '<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M10 7h6M10 12h6M10 17h6"/><path d="M7 7h.01M7 12h.01M7 17h.01"/>',
    'sales':
        '<rect x="3" y="14" width="4" height="8" rx="1"/><rect x="10" y="8" width="4" height="14" rx="1"/><rect x="17" y="2" width="4" height="20" rx="1"/>',
    'join':
        '<circle cx="10" cy="7" r="4"/><path d="M2 22v-3a6 6 0 0 1 6-6h4a6 6 0 0 1 4 1.5M18 15v8M14 19h8M2 22h10"/>',
  };
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round">${paths[name]}</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
