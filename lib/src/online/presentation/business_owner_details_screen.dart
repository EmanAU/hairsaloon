import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/pk_cnic.dart';
import '../../core/utils/pk_phone.dart';
import '../../features/business_profile/presentation/state/business_profile_notifier.dart';
import '../../theme/app_colors.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import 'business_form.dart';
import 'widgets/business_photo.dart';
import 'widgets/online_widgets.dart';

class BusinessOwnerDetailsScreen extends StatefulWidget {
  const BusinessOwnerDetailsScreen({super.key, required this.workspace});
  final BusinessWorkspace workspace;
  @override
  State<BusinessOwnerDetailsScreen> createState() =>
      _BusinessOwnerDetailsScreenState();
}

class _BusinessOwnerDetailsScreenState
    extends State<BusinessOwnerDetailsScreen> {
  late Future<OnlineWorkspace> _details = widget.workspace.repository
      .loadWorkspace();
  late Future<String?> _photo = widget.workspace.repository.profilePhoto();
  bool _editing = false;

  Future<void> _reload() async {
    final future = widget.workspace.repository.loadWorkspace();
    setState(() {
      _details = future;
      _photo = widget.workspace.repository.profilePhoto();
    });
    try {
      final account = await future;
      if (!mounted) return;
      final updated = account.businesses
          .where((b) => b.id == widget.workspace.business.id)
          .firstOrNull;
      if (updated != null && !account.isCached) {
        final profileNotifier = context.read<BusinessProfileNotifier?>();
        await widget.workspace.updateBusiness(updated);
        await profileNotifier?.load();
      }
    } catch (_) {
      /* The page keeps its inline retry action if refresh fails. */
    }
  }

  Future<void> _edit(SalonBusiness business) async {
    if (_editing) return;
    _editing = true;
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessForm(
            repository: widget.workspace.repository,
            business: business,
          ),
        ),
      );
      if (saved == true && mounted) await _reload();
    } finally {
      _editing = false;
    }
  }

  String _date(DateTime? value) => value == null
      ? 'Not set'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(CupertinoIcons.back),
      ),
      title: Text(
        'Business Details',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          child: RemoteContent<OnlineWorkspace>(
            future: _details,
            onRetry: _reload,
            builder: (account) {
              final owned = account.businesses
                  .where((b) => b.id == widget.workspace.business.id)
                  .firstOrNull;
              final business = owned ?? widget.workspace.business;
              final profile = account.profile;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 172,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 124,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Color(0xFFEEFAC9)),
                                if (business.logoPath != null)
                                  ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(
                                      sigmaX: 14,
                                      sigmaY: 14,
                                    ),
                                    child: BusinessPhoto(
                                      repository: widget.workspace.repository,
                                      business: business,
                                      width: double.infinity,
                                      height: 124,
                                      borderRadius: 0,
                                    ),
                                  ),
                                const ColoredBox(color: Color(0x66E9FFAD)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: BusinessPhoto(
                              repository: widget.workspace.repository,
                              business: business,
                              width: 78,
                              height: 78,
                              borderRadius: 20,
                              placeholderIcon: CupertinoIcons.building_2_fill,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                business.isActive
                                    ? CupertinoIcons.checkmark_seal_fill
                                    : CupertinoIcons.clock,
                                size: 14,
                                color: AppColors.homeOlive,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                business.isActive
                                    ? 'Approved'
                                    : 'Awaiting approval',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.homeOlive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    business.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                      color: AppColors.homeInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${business.type} · ${business.area}, ${business.city}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (owned != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _edit(business),
                      icon: const Icon(CupertinoIcons.pencil, size: 17),
                      label: const Text('Edit business'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.homeInk,
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  const _SectionLabel('Business information'),
                  _DetailTile(
                    'Business phone',
                    PkPhone.localNumber(business.phone),
                    CupertinoIcons.phone,
                  ),
                  _DetailTile(
                    'Business type',
                    business.type,
                    CupertinoIcons.square_grid_2x2,
                  ),
                  _DetailTile(
                    'City',
                    business.city,
                    CupertinoIcons.building_2_fill,
                  ),
                  _DetailTile('Area', business.area, CupertinoIcons.location),
                  _DetailTile(
                    'Address',
                    business.address,
                    CupertinoIcons.location_solid,
                  ),
                  const SizedBox(height: 24),
                  if (owned != null) ...[
                    const _SectionLabel('Owner details'),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 10),
                      child: Row(
                        children: [
                          FutureBuilder<String?>(
                            future: _photo,
                            builder: (_, snapshot) {
                              const placeholder = ColoredBox(
                                color: Color(0xFFF0F4E8),
                                child: Icon(
                                  CupertinoIcons.person_crop_circle,
                                  color: AppColors.homeOlive,
                                  size: 26,
                                ),
                              );
                              return ClipOval(
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: snapshot.data == null
                                      ? placeholder
                                      : Image.network(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, error, stack) =>
                                              placeholder,
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.account.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.homeInk,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Business owner',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DetailTile(
                      'Personal phone',
                      PkPhone.localNumber(profile?.phone),
                      CupertinoIcons.phone,
                    ),
                    _DetailTile(
                      'CNIC',
                      PkCnic.display(profile?.cnic ?? ''),
                      CupertinoIcons.person_crop_rectangle,
                    ),
                    _DetailTile(
                      'Date of birth',
                      _date(profile?.dateOfBirth),
                      CupertinoIcons.calendar,
                    ),
                    _DetailTile(
                      'Working since',
                      _date(profile?.workStartedOn),
                      CupertinoIcons.briefcase,
                    ),
                    _DetailTile(
                      'Experience',
                      profile?.experienceAt(DateTime.now()) ?? 'Not set',
                      CupertinoIcons.time,
                    ),
                  ] else
                    const Text(
                      'The owner’s personal details are private.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 18),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text(
                      'Reference details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      _DetailTile(
                        'Business ID',
                        business.id,
                        CupertinoIcons.qrcode,
                      ),
                      if (owned != null)
                        _DetailTile(
                          'Profile code',
                          profile?.code ?? '',
                          CupertinoIcons.person_crop_square,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -.25,
        color: AppColors.homeInk,
      ),
    ),
  );
}

class _DetailTile extends StatelessWidget {
  const _DetailTile(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 18, color: AppColors.homeOlive),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    value.trim().isEmpty ? 'Not set' : value,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.homeInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 32),
        child: Divider(height: 1, color: Color(0xFFEEF0EB)),
      ),
    ],
  );
}
