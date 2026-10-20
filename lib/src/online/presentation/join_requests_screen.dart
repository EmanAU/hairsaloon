import 'dart:async';
import 'package:flutter/material.dart';
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
    borderRadius: BorderRadius.circular(6),
    side: const BorderSide(color: AppColors.homeBorder),
  );

  Future<List<SalonStaff>> _load() =>
      widget.repository.team(widget.businessId);

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

  void _refresh() => setState(() => _staff = _load());

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
              style: text.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                        borderRadius: BorderRadius.circular(6),
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
                        borderRadius: BorderRadius.circular(6),
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
          final pending =
              staff.where((e) => e.joinStatus == 'pending').toList();
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
