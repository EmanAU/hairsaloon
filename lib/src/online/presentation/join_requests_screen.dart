import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/utils/pk_phone.dart';
import '../../core/utils/pk_cnic.dart';
import 'package:provider/provider.dart';
import '../../core/services/toast_service.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'contracts_screen.dart';
import 'widgets/online_widgets.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({
    super.key,
    required this.repository,
    required this.businessId,
    this.workspace,
  });

  final OnlineRepository repository;
  final String businessId;
  final BusinessWorkspace? workspace;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late Future<List<SalonStaff>> _staff = _load();
  late final Timer _poll;
  String? _reviewing;
  static final _tileShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: const BorderSide(color: AppColors.homeBorder),
  );

  Future<List<SalonStaff>> _load() => widget.repository.team(widget.businessId);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _reviewing == null &&
          ModalRoute.of(context)?.isCurrent == true) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  void _refresh() => setState(() {
    _staff = _load();
  });

  Future<void> _syncLocal() async {
    try {
      await widget.workspace?.syncOnlineTeam();
    } catch (_) {}
    if (!mounted) return;
    try {
      context.read<EmployeesStore>().refresh();
    } catch (_) {}
  }

  Future<void> _review(SalonStaff employee, bool accept) async {
    if (_reviewing != null) return;
    setState(() => _reviewing = employee.id);
    try {
      await widget.repository.reviewJoin(employee.id, accept);
    } on OnlineFailure catch (error) {
      if (mounted) {
        ToastService.error(error.message, context);
        setState(() => _reviewing = null);
      }
      return;
    } catch (_) {
      if (mounted) {
        ToastService.error(
          'Could not update this request. Try again.',
          context,
        );
        setState(() => _reviewing = null);
      }
      return;
    }

    // Accept/decline already committed — never surface follow-up noise as failure.
    await _syncLocal();
    if (!mounted) return;
    ToastService.success(
      accept ? 'Request accepted' : 'Request declined',
      context,
    );
    _refresh();
    setState(() => _reviewing = null);
    if (!accept) return;
    final business = widget.workspace?.business;
    if (business != null) {
      await pushProposeContractFlow(
        context,
        repository: widget.repository,
        business: business,
        employee: employee,
        account: widget.workspace?.account,
      );
    } else {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProposeContractPage(
            repository: widget.repository,
            employee: employee,
          ),
        ),
      );
    }
  }

  Widget _tile(SalonStaff employee) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: _tileShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wants to join your salon',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (detailContext) => _JoinRequestDetails(
                    employee: employee,
                    onReview: (accept) async {
                      Navigator.pop(detailContext);
                      await _review(employee, accept);
                    },
                  ),
                ),
              ),
              icon: const Icon(CupertinoIcons.person_crop_rectangle, size: 18),
              label: const Text('View details'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: AppColors.homeInk,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: 'Decline',
                    icon: Icons.close,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _review(employee, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ActionButton(
                    label: 'Accept',
                    icon: Icons.check,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _review(employee, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Join requests',
    actions: [
      IconButton(
        tooltip: 'Refresh',
        onPressed: _reviewing == null ? _refresh : null,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      RemoteContent<List<SalonStaff>>(
        future: _staff,
        onRetry: _refresh,
        builder: (staff) {
          final pending = staff
              .where((e) => e.joinStatus == 'pending')
              .toList();
          return AbsorbPointer(
            absorbing: _reviewing != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No pending join requests.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (var i = 0; i < pending.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _tile(pending[i]),
                  ],
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _JoinRequestDetails extends StatelessWidget {
  const _JoinRequestDetails({required this.employee, required this.onReview});
  final SalonStaff employee;
  final Future<void> Function(bool accept) onReview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.homeOlive),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: text.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Join request details',
          style: text.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8DD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(
                          CupertinoIcons.person,
                          size: 29,
                          color: AppColors.homeOlive,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        employee.name,
                        style: text.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pending approval',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.homeOlive,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Employee details',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                line(
                  CupertinoIcons.phone,
                  'Phone number',
                  PkPhone.localNumber(employee.phone),
                ),
                const Divider(height: 1, color: AppColors.border),
                line(
                  CupertinoIcons.person_crop_rectangle,
                  'CNIC',
                  PkCnic.display(employee.cnic),
                ),
                const Divider(height: 1, color: AppColors.border),
                line(CupertinoIcons.person_2, 'Joining as', 'Employee'),
                const SizedBox(height: 20),
                Text(
                  'Accept to add this person to your team. You can set their salary, commission and contract next.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  label: 'Accept & set contract',
                  showIcon: false,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => onReview(true),
                ),
                ActionButton(
                  label: 'Decline request',
                  showIcon: false,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F2),
                    foregroundColor: AppColors.homeInk,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => onReview(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
