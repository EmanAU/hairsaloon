import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/toast_service.dart';
import '../../core/widgets/app_sheet.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/qr_destination.dart';
import 'qr_screen.dart';
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
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose how you want to invite them.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InviteOptionTile(
            icon: Icons.person_add_outlined,
            title: 'New person (not registered)',
            subtitle: 'CNIC, phone and email',
            onTap: () => Navigator.pop(context, 'identity'),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _InviteOptionTile(
            icon: Icons.badge_outlined,
            title: 'Invite by profile code',
            subtitle: 'Enter their TrimMatrix profile code',
            onTap: () => Navigator.pop(context, 'code'),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _InviteOptionTile(
            icon: Icons.qr_code_scanner,
            title: 'Invite by QR code',
            subtitle: 'Scan their profile QR',
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
        await workspace.syncOnlineTeam();
        if (context.mounted) {
          try {
            context.read<EmployeesStore>().refresh();
          } catch (_) {}
          ToastService.success('Employee added to your salon', context);
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
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
    );
  }
}

Future<void> _afterInvite(BuildContext context, BusinessWorkspace workspace) async {
  await workspace.syncOnlineTeam();
  if (!context.mounted) return;
  try {
    context.read<EmployeesStore>().refresh();
  } catch (_) {}
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
    if (!_email.text.contains('@')) {
      throw const OnlineFailure('Enter a valid email');
    }
    await widget.workspace.repository.inviteEmployeeByIdentity(
      businessId: widget.workspace.business.id,
      cnic: _cnic.text,
      phone: _phone.text,
      email: _email.text,
      name: _name.text,
    );
    if (!mounted) return;
    await _afterInvite(context, widget.workspace);
    if (!mounted) return;
    ToastService.success(
      'Invite saved. They can join after completing their profile.',
      context,
    );
    Navigator.pop(context);
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Invite new person',
    children: [
      Text(
        'If they are not on TrimMatrix yet, enter CNIC, phone and email. '
        'They will see a join offer after installing the app and completing their profile.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: _decoration('Full name (optional)'),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _cnic,
        keyboardType: TextInputType.number,
        maxLength: 13,
        decoration: _decoration('CNIC (13 digits)').copyWith(counterText: ''),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: _decoration('Mobile number', hint: '03127712502'),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: _decoration('Email'),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ActionButton(
          label: 'Send invite',
          icon: Icons.person_add_outlined,
          onPressed: _submit,
        ),
      ),
    ],
  );
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
    await _afterInvite(context, widget.workspace);
    if (!mounted) return;
    ToastService.success('Employee added to your salon', context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Invite by profile code',
    children: [
      Text(
        'Paste their TrimMatrix profile code to add them to this salon.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _code,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Employee profile code',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ActionButton(
          label: 'Add employee',
          icon: Icons.badge_outlined,
          onPressed: _submit,
        ),
      ),
    ],
  );
}
