import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/pk_phone.dart';
import '../../core/widgets/app_sheet.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/qr_destination.dart';
import 'qr_screen.dart';
import 'contracts_screen.dart';
import 'widgets/online_widgets.dart';

Future<void> showEmployeeInviteOptions(BuildContext context) async {
  final workspace = context.read<BusinessWorkspace?>();
  if (workspace == null) return;
  final choice = await showAppSheet<String>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add employee',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Invite someone new, or someone already on TrimMatrix.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InviteOptionTile(
            icon: Icons.person_add_alt_1_outlined,
            title: 'New person',
            subtitle: 'Fill their details and send an invite',
            onTap: () => Navigator.pop(context, 'identity'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InviteOptionTile(
            icon: Icons.badge_outlined,
            title: 'Profile code',
            subtitle: 'Paste their TrimMatrix profile code',
            onTap: () => Navigator.pop(context, 'code'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InviteOptionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR',
            subtitle: 'Scan their profile QR code',
            onTap: () => Navigator.pop(context, 'qr'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'identity':
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _IdentityInvitePage(workspace: workspace),
        ),
      );
    case 'code':
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _ProfileCodeInvitePage(workspace: workspace),
        ),
      );
    case 'qr':
      final scanned = await Navigator.push<QrDestination>(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanQr(profileCode: true),
        ),
      );
      if (scanned == null || !context.mounted) return;
      try {
        await workspace.repository.inviteEmployee(
          workspace.business.id,
          scanned.id,
        );
        if (context.mounted) {
          ToastService.success('Employee added to your salon', context);
          await _afterInvite(context, workspace);
        }
      } catch (error) {
        if (context.mounted) {
          ToastService.error(
            error is OnlineFailure
                ? error.message
                : 'Could not add this employee. Try again.',
            context,
          );
        }
      }
  }
}

class _InviteOptionTile extends StatelessWidget {
  const _InviteOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _afterInvite(
  BuildContext context,
  BusinessWorkspace workspace,
) async {
  await workspace.syncOnlineTeam();
  if (!context.mounted) return;
  try {
    context.read<EmployeesStore>().refresh();
  } catch (_) {}
  if (!context.mounted) return;

  // Profile-code / QR adds join immediately — continue to contract → details.
  final team = await workspace.repository.team(workspace.business.id);
  if (!context.mounted) return;
  SalonStaff? match;
  for (final member in team) {
    if (member.joinStatus == 'accepted' && !member.isWorking) {
      match = member;
      break;
    }
  }
  if (match == null || !context.mounted) return;
  await pushProposeContractFlow(
    context,
    repository: workspace.repository,
    business: workspace.business,
    employee: match,
    account: workspace.account,
  );
}

class _IdentityInvitePage extends StatefulWidget {
  const _IdentityInvitePage({required this.workspace});
  final BusinessWorkspace workspace;

  @override
  State<_IdentityInvitePage> createState() => _IdentityInvitePageState();
}

class _IdentityInvitePageState extends State<_IdentityInvitePage> {
  final _name = TextEditingController();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!RegExp(r'^\d{13}$').hasMatch(_cnic.text.trim())) {
      throw const OnlineFailure('Enter a valid 13-digit CNIC');
    }
    final phoneError = PkPhone.localValidationError(_phone.text);
    if (phoneError != null) {
      throw OnlineFailure(phoneError);
    }
    if (!_email.text.contains('@')) {
      throw const OnlineFailure('Enter a valid email');
    }
    await widget.workspace.repository.inviteEmployeeByIdentity(
      businessId: widget.workspace.business.id,
      cnic: _cnic.text,
      phone: PkPhone.normalize(_phone.text),
      email: _email.text,
      name: _name.text,
    );
    if (!mounted) return;
    if (!mounted) return;
    ToastService.success(
      'Invite sent. They will confirm before joining your salon.',
      context,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(
          'Invite new person',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: OnlineShell.centered(
        maxWidth: OnlineShell.formMaxWidth,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  const _FieldLabel('Details'),
                  const SizedBox(height: AppSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: appSheetInputDecoration(
                              'Full name',
                              hint: 'Optional',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cnic,
                            keyboardType: TextInputType.number,
                            maxLength: 13,
                            textInputAction: TextInputAction.next,
                            decoration: appSheetInputDecoration(
                              'CNIC',
                              hint: '13 digits',
                            ).copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: appSheetInputDecoration(
                              'Mobile number',
                              hint: '03124545452',
                            ).copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            decoration: appSheetInputDecoration(
                              'Email',
                              hint: 'name@example.com',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ActionButton(
                    label: 'Send invite',
                    showIcon: false,
                    style: appPrimaryButtonStyle(),
                    onPressed: _submit,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ProfileCodeInvitePage extends StatefulWidget {
  const _ProfileCodeInvitePage({required this.workspace});
  final BusinessWorkspace workspace;

  @override
  State<_ProfileCodeInvitePage> createState() => _ProfileCodeInvitePageState();
}

class _ProfileCodeInvitePageState extends State<_ProfileCodeInvitePage> {
  final _code = TextEditingController();
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _code.text.trim();
    if (!_uuid.hasMatch(value)) {
      throw const OnlineFailure('Paste a valid profile code');
    }
    await widget.workspace.repository.inviteEmployee(
      widget.workspace.business.id,
      value,
    );
    if (!mounted) return;
    if (!mounted) return;
    ToastService.success('Employee added to your salon', context);
    await _afterInvite(context, widget.workspace);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.homeCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.homeCanvas,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(
          'Invite by profile code',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: OnlineShell.centered(
        maxWidth: OnlineShell.formMaxWidth,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Text(
                    'Paste their TrimMatrix profile code to add them to this salon.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: TextField(
                        controller: _code,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        decoration: appSheetInputDecoration(
                          'Profile code',
                          hint: 'Paste code here',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ActionButton(
                    label: 'Add employee',
                    icon: Icons.badge_outlined,
                    style: appPrimaryButtonStyle(),
                    onPressed: _submit,
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
