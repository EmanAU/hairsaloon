import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/employees/domain/entities/employee_item.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'contracts_screen.dart';
import 'widgets/online_widgets.dart';

/// Accepted team members; tap opens that employee's contracts.
class TeamContractsScreen extends StatefulWidget {
  const TeamContractsScreen({
    super.key,
    required this.repository,
    required this.businessId,
    this.business,
  });

  final OnlineRepository repository;
  final String businessId;
  final SalonBusiness? business;

  @override
  State<TeamContractsScreen> createState() => _TeamContractsScreenState();
}

class _TeamContractsScreenState extends State<TeamContractsScreen> {
  late Future<List<SalonStaff>> _staff = _load();
  late final Timer _poll;

  Future<List<SalonStaff>> _load() => widget.repository.team(widget.businessId);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
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

  Future<void> _openContracts(SalonStaff employee) async {
    final business = widget.business;
    if (!employee.isWorking && business != null) {
      await pushProposeContractFlow(
        context,
        repository: widget.repository,
        business: business,
        employee: employee,
      );
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ContractsScreen(
            repository: widget.repository,
            employee: employee,
          ),
        ),
      );
    }
    if (mounted) _refresh();
  }

  Widget _row(SalonStaff employee) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.homeBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openContracts(employee),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.homeSage,
                child: Icon(
                  employee.isManager
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  color: AppColors.homeInk,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.isManager
                          ? '${employee.name} · Manager'
                          : employee.name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.isWorking
                          ? 'Working · active contract'
                          : 'Joined · contract not set',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Contracts',
    actions: [
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      Text(
        'Select an employee to view or edit their contracts.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final employee
          in context.watch<EmployeesStore?>()?.employees.where(
                (e) => !e.onlineSynced,
              ) ??
              const <EmployeeItem>[]) ...[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(employee.fullName),
          subtitle: Text(
            employee.contract == null
                ? 'Set employment terms'
                : 'Contract saved · account not linked yet',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ProposeContractPage(
                repository: widget.repository,
                business: widget.business,
                localEmployee: employee,
                employee: SalonStaff(
                  id: employee.id,
                  name: employee.fullName,
                  isWorking: false,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      RemoteContent<List<SalonStaff>>(
        future: _staff,
        onRetry: _refresh,
        builder: (staff) {
          final employees = staff
              .where((e) => e.joinStatus == 'accepted')
              .toList();
          if (employees.isEmpty &&
              (context.read<EmployeesStore?>()?.employees.isEmpty ?? true)) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No employees yet. Invite staff from Employees.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < employees.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _row(employees[i]),
              ],
            ],
          );
        },
      ),
    ],
  );
}
