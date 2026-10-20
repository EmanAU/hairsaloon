import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/toast_service.dart';
import '../../core/widgets/app_sheet.dart';
import '../../features/employees/data/repositories/hive_employees_repository.dart';
import '../../features/employees/domain/entities/employee_item.dart';
import '../../features/employees/presentation/employee_details_screen.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key, required this.repository, this.employee});
  final OnlineRepository repository;
  final SalonStaff? employee;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  late Future<List<WorkContract>> _contracts = _load();
  Future<List<WorkContract>> _load() =>
      widget.repository.contracts(employeeId: widget.employee?.id);
  void _refresh() => setState(() => _contracts = _load());

  Future<void> _openPropose() async {
    final employee = widget.employee;
    if (employee == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProposeContractPage(
          repository: widget.repository,
          employee: employee,
        ),
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _release(WorkContract contract) async {
    final reason = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ReleaseReason()),
    );
    if (reason == null) return;
    try {
      await widget.repository.releaseContract(contract.id, reason);
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
      return;
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not release this contract. Try again.', context);
      }
      return;
    }
    if (!mounted) return;
    ToastService.success('Contract released', context);
    _refresh();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: widget.employee?.name ?? 'My contracts',
    actions: [
      IconButton(
        tooltip: 'Refresh contracts',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      if (widget.employee != null) ...[
        SizedBox(
          width: double.infinity,
          child: ActionButton(
            label: 'Propose contract',
            icon: Icons.add,
            style: appPrimaryButtonStyle(),
            onPressed: _openPropose,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      RemoteContent<List<WorkContract>>(
        future: _contracts,
        onRetry: _refresh,
        builder: (contracts) => contracts.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No contracts yet.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < contracts.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _ContractDetailCard(
                      contract: contracts[i],
                      onRelease: widget.employee != null &&
                              contracts[i].canRelease
                          ? () => _release(contracts[i])
                          : null,
                    ),
                  ],
                ],
              ),
      ),
    ],
  );
}

class _ContractDetailCard extends StatelessWidget {
  const _ContractDetailCard({required this.contract, this.onRelease});

  final WorkContract contract;
  final Future<void> Function()? onRelease;

  String get _kindLabel => switch (contract.kind) {
    'permanent' => 'Permanent',
    'daily' => 'Daily',
    'fixed' => 'Fixed term',
    _ => contract.kind,
  };

  String get _statusLabel => switch (contract.displayStatus) {
    'active' => 'Active',
    'scheduled' => 'Scheduled',
    'expired' => 'Expired',
    'released' => 'Released',
    'draft' => 'Draft',
    'declined' => 'Declined',
    _ => contract.displayStatus,
  };

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} · $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailRow(label: 'Salon', value: contract.businessName),
            _DetailRow(label: 'Employment type', value: _kindLabel),
            _DetailRow(label: 'Status', value: _statusLabel),
            _DetailRow(label: 'From', value: _formatDate(contract.startsAt)),
            _DetailRow(
              label: 'To',
              value: contract.endsAt == null
                  ? 'Until released'
                  : _formatDate(contract.endsAt!),
            ),
            _DetailRow(
              label: 'Salary',
              value: contract.salary.toStringAsFixed(0),
            ),
            _DetailRow(
              label: 'Commission',
              value: '${contract.commission.toStringAsFixed(0)}%',
            ),
            if (contract.terms.trim().isNotEmpty)
              _DetailRow(
                label: 'Agreement description',
                value: contract.terms.trim(),
              ),
            if (contract.endingSoon) ...[
              const SizedBox(height: 8),
              Text(
                'This contract ends within 7 days.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.homeBronze,
                ),
              ),
            ],
            if (contract.releaseReason != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Release reason',
                value: contract.releaseReason!,
              ),
            ],
            if (onRelease != null) ...[
              const SizedBox(height: 12),
              ActionButton(
                label: 'Release employee',
                icon: Icons.person_off_outlined,
                onPressed: onRelease!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseReason extends StatefulWidget {
  const _ReleaseReason();
  @override
  State<_ReleaseReason> createState() => _ReleaseReasonState();
}

class _ReleaseReasonState extends State<_ReleaseReason> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Release employee',
    children: [
      const Text(
        'This ends the contract now. Its history will remain available.',
      ),
      const SizedBox(height: AppSpacing.md),
      Form(
        key: _form,
        child: TextFormField(
          controller: _reason,
          decoration: appSheetInputDecoration('Reason for release'),
          maxLength: 1000,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'A reason is required'
              : null,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: appPrimaryButtonStyle(),
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _reason.text.trim());
            }
          },
          child: const Text('Confirm release'),
        ),
      ),
    ],
  );
}

/// Opens contract → required employee details, ensuring [EmployeesStore] exists.
Future<bool?> pushProposeContractFlow(
  BuildContext context, {
  required OnlineRepository repository,
  required SalonBusiness business,
  required SalonStaff employee,
  OnlineAccount? account,
}) async {
  BusinessWorkspace? ownedWorkspace;
  try {
    EmployeesStore? existing;
    try {
      existing = context.read<EmployeesStore>();
    } catch (_) {}
    if (existing != null) {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProposeContractPage(
            repository: repository,
            employee: employee,
            business: business,
          ),
        ),
      );
    }

    final workspaceAccount =
        account ?? (await repository.loadWorkspace()).account;
    final workspace = await BusinessWorkspace.open(
      repository,
      business,
      workspaceAccount,
    );
    ownedWorkspace = workspace;
    await workspace.syncOnlineTeam();
    if (!context.mounted) {
      workspace.dispose();
      return null;
    }
    final store = EmployeesStore(
      repository: HiveEmployeesRepository(
        box: workspace.maps['employees'],
        metaBox: workspace.settings,
      ),
    );
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<BusinessWorkspace?>.value(value: workspace),
            ChangeNotifierProvider<EmployeesStore>.value(value: store),
          ],
          child: ProposeContractPage(
            repository: repository,
            employee: employee,
            business: business,
          ),
        ),
      ),
    );
    return result;
  } finally {
    ownedWorkspace?.dispose();
  }
}

/// Owner form to set employment terms for an accepted team member.
class ProposeContractPage extends StatefulWidget {
  const ProposeContractPage({
    super.key,
    required this.repository,
    required this.employee,
    this.business,
  });

  final OnlineRepository repository;
  final SalonStaff employee;
  final SalonBusiness? business;

  @override
  State<ProposeContractPage> createState() => _ProposeContractPageState();
}

class _ProposeContractPageState extends State<ProposeContractPage> {
  final _form = GlobalKey<FormState>();
  final _salary = TextEditingController(text: '0');
  final _commission = TextEditingController(text: '0');
  final _terms = TextEditingController();
  String _kind = 'permanent';
  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _salary.dispose();
    _commission.dispose();
    _terms.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} · $h:$min';
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _starts : _ends;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final selected = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _starts = selected;
      } else {
        _ends = selected;
      }
    });
  }

  String? _number(String? value, double maximum) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null ||
            !number.isFinite ||
            number < 0 ||
            number > maximum ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())
        ? 'Enter a valid amount up to $maximum'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ends = _kind == 'permanent'
        ? null
        : _kind == 'daily'
        ? _starts.add(const Duration(hours: 24))
        : _ends;
    if (ends != null &&
        (!ends.isAfter(_starts) || !ends.isAfter(DateTime.now()))) {
      ToastService.error(
        'End time must be after the start time and in the future.',
        context,
      );
      return;
    }
    try {
      await widget.repository.proposeContract(
        employeeId: widget.employee.id,
        kind: _kind,
        starts: _starts,
        ends: ends,
        salary: double.parse(_salary.text),
        commission: double.parse(_commission.text),
        terms: _terms.text,
      );
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
      return;
    } catch (_) {
      if (mounted) {
        ToastService.error(
          'Could not save the contract. Try again.',
          context,
        );
      }
      return;
    }
    if (!mounted) return;
    ToastService.success('Contract saved', context);
    await _openCompleteProfile();
  }

  EmployeeItem _employeeItemFromLocal() {
    final staff = widget.employee;
    final parts = staff.name.trim().split(RegExp(r'\s+'));
    final first =
        parts.isEmpty || parts.first.isEmpty ? 'Staff' : parts.first;
    final last = parts.length <= 1 ? '' : parts.sublist(1).join(' ');

    EmployeesStore? store;
    try {
      store = context.read<EmployeesStore>();
    } catch (_) {}
    final existing = store?.byId(staff.id);
    if (existing != null) {
      return existing.copyWith(
        basicSalary: _salary.text.trim(),
        commission: _commission.text.trim(),
        agreementDescription: _terms.text.trim(),
      );
    }

    BusinessWorkspace? workspace;
    try {
      workspace = context.read<BusinessWorkspace?>();
    } catch (_) {}
    final row = workspace?.maps['employees']?.get(staff.id);
    if (row != null) {
      final map = Map<String, dynamic>.from(row);
      return EmployeeItem(
        id: staff.id,
        firstName: (map['firstName'] as String?)?.trim().isNotEmpty == true
            ? map['firstName'] as String
            : first,
        lastName: (map['lastName'] as String?) ?? last,
        phoneNumber: (map['phoneNumber'] as String?) ?? '',
        cnicNumber: (map['cnicNumber'] as String?) ?? '',
        homeAddress: (map['homeAddress'] as String?) ?? '',
        isActive: map['isActive'] as bool? ?? true,
        isManager: map['isManager'] as bool? ?? false,
        photoBase64: map['photoBase64'] as String?,
        speciality: map['speciality'] as String?,
        employeeType: (map['employeeType'] as String?) ?? 'General',
        basicSalary: _salary.text.trim(),
        commission: _commission.text.trim(),
        agreementDescription: _terms.text.trim(),
      );
    }

    return EmployeeItem(
      id: staff.id,
      firstName: first,
      lastName: last,
      phoneNumber: staff.phone,
      cnicNumber: staff.cnic,
      homeAddress: '',
      isActive: true,
      employeeType: 'General',
      basicSalary: _salary.text.trim(),
      commission: _commission.text.trim(),
      agreementDescription: _terms.text.trim(),
    );
  }

  Future<void> _openCompleteProfile() async {
    BusinessWorkspace? workspace;
    EmployeesStore? store;
    BusinessWorkspace? ownedWorkspace;
    try {
      workspace = context.read<BusinessWorkspace?>();
    } catch (_) {}
    try {
      store = context.read<EmployeesStore>();
    } catch (_) {}

    var item = _employeeItemFromLocal();

    try {
      await workspace?.syncOnlineTeam();
    } catch (_) {}

    if (store == null && widget.business != null) {
      try {
        final account = (await widget.repository.loadWorkspace()).account;
        ownedWorkspace = await BusinessWorkspace.open(
          widget.repository,
          widget.business!,
          account,
        );
        workspace = ownedWorkspace;
        await ownedWorkspace.syncOnlineTeam();
        store = EmployeesStore(
          repository: HiveEmployeesRepository(
            box: ownedWorkspace.maps['employees'],
            metaBox: ownedWorkspace.settings,
          ),
        );
      } catch (_) {
        ownedWorkspace?.dispose();
        ownedWorkspace = null;
      }
    }

    if (store != null) {
      final known = store.byId(item.id);
      if (known == null) {
        await store.add(item);
      } else {
        final merged = known.copyWith(
          phoneNumber: known.phoneNumber.trim().isEmpty
              ? item.phoneNumber
              : known.phoneNumber,
          cnicNumber: known.cnicNumber.trim().isEmpty
              ? item.cnicNumber
              : known.cnicNumber,
          basicSalary: item.basicSalary,
          commission: item.commission,
          agreementDescription: item.agreementDescription,
        );
        await store.update(merged);
        item = merged;
      }
      store.refresh();
    } else if (workspace != null) {
      final box = workspace.maps['employees'];
      if (box != null) {
        await box.put(item.id, <String, dynamic>{
          'id': item.id,
          'firstName': item.firstName,
          'lastName': item.lastName,
          'phoneNumber': item.phoneNumber,
          'cnicNumber': item.cnicNumber,
          'homeAddress': item.homeAddress,
          'isActive': item.isActive,
          'isManager': item.isManager,
          'onlineSynced': true,
          'commission': item.commission ?? '',
          'basicSalary': item.basicSalary ?? '',
          'agreementDescription': item.agreementDescription ?? '',
          'employeeType': item.employeeType ?? 'General',
          'speciality': item.speciality,
          'photoBase64': item.photoBase64,
        });
      }
    }

    if (!mounted) {
      ownedWorkspace?.dispose();
      return;
    }

    if (store == null) {
      ToastService.info(
        'Finish their profile in Billing → Employees.',
        context,
      );
      Navigator.pop(context, true);
      ownedWorkspace?.dispose();
      return;
    }

    final fresh = store.byId(item.id) ?? item;
    final detailsStore = store;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<EmployeeItem>(
        builder: (_) => ChangeNotifierProvider<EmployeesStore>.value(
          value: detailsStore,
          child: EmployeeDetailsScreen(
            item: fresh,
            requireCompletion: true,
          ),
        ),
      ),
    );
    ownedWorkspace?.dispose();
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
          'Propose contract',
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.homeSage,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: AppColors.homeOlive,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.employee.name,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.homeInk,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Set employment terms. They take effect immediately.',
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.homeOlive,
                                    height: 1.4,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Terms',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _kind,
                            decoration: appSheetInputDecoration(
                              'Contract type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'permanent',
                                child: Text('Permanent'),
                              ),
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('Daily (24 hours)'),
                              ),
                              DropdownMenuItem(
                                value: 'fixed',
                                child: Text('Fixed term'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _kind = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          _DateFieldTile(
                            label: 'Start date',
                            value: _formatDateTime(_starts),
                            onTap: () => _pickDate(true),
                          ),
                          if (_kind == 'fixed') ...[
                            const SizedBox(height: 12),
                            _DateFieldTile(
                              label: 'End date',
                              value: _formatDateTime(_ends),
                              onTap: () => _pickDate(false),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _salary,
                            decoration: appSheetInputDecoration(
                              'Basic salary',
                              hint: '0',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) =>
                                _number(value, 9999999999.99),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _commission,
                            decoration: appSheetInputDecoration(
                              'Commission (%)',
                              hint: '0',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) => _number(value, 100),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _terms,
                            decoration: appSheetInputDecoration(
                              'Agreement description',
                              hint: 'Optional notes',
                            ),
                            minLines: 3,
                            maxLines: 6,
                          ),
                        ],
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
                  label: 'Save contract',
                  icon: Icons.check_rounded,
                  style: appPrimaryButtonStyle(),
                  onPressed: _save,
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

class _DateFieldTile extends StatelessWidget {
  const _DateFieldTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                size: 20,
                color: AppColors.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
