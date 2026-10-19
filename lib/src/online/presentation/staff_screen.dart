import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/employees/presentation/state/employees_store.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'contracts_screen.dart';
import 'widgets/online_widgets.dart';
import 'qr_screen.dart';
import '../domain/qr_destination.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({
    super.key,
    required this.repository,
    required this.businessId,
    this.showRequests,
    this.workspace,
  });
  final OnlineRepository repository;
  final String businessId;
  final bool? showRequests;
  final BusinessWorkspace? workspace;
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<List<SalonStaff>> _staff = widget.repository.team(
    widget.businessId,
  );
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  late bool? _requests = widget.showRequests;
  String? _reviewing;
  late final Timer _poll;
  final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

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

  void _refresh() => setState(() {
    _staff = widget.repository.team(widget.businessId);
  });
  @override
  void dispose() {
    _poll.cancel();
    _code.dispose();
    _name.dispose();
    _cnic.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _syncLocalBillingStaff() async {
    await widget.workspace?.syncOnlineTeam();
    if (!mounted) return;
    try {
      context.read<EmployeesStore>().refresh();
    } catch (_) {
      // Billing store only exists inside the workspace dashboard.
    }
  }

  Future<void> _review(SalonStaff employee, bool accept) async {
    if (_reviewing != null) return;
    setState(() => _reviewing = employee.id);
    try {
      await widget.repository.reviewJoin(employee.id, accept);
      await _syncLocalBillingStaff();
      if (mounted) {
        showMessage(context, accept ? 'Request accepted' : 'Request declined');
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is OnlineFailure
              ? error.message
              : 'Could not update this request. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _reviewing = null);
    }
  }

  Widget _requestCard(SalonStaff employee) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFFE3E7EC)),
    ),
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            employee.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wants to join your salon',
            style: TextStyle(color: Color(0xFF718094)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: 'Decline',
                  icon: Icons.close,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F5F7),
                    foregroundColor: Colors.black,
                    shape: _shape,
                  ),
                  onPressed: () => _review(employee, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionButton(
                  label: 'Accept',
                  icon: Icons.check,
                  style: FilledButton.styleFrom(shape: _shape),
                  onPressed: () => _review(employee, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _setManager(SalonStaff employee) async {
    if (employee.isManager) {
      await widget.repository.setEmployeeManager(
        employeeId: employee.id,
        isManager: false,
      );
      if (mounted) {
        showMessage(context, 'Manager access removed');
        _refresh();
      }
      return;
    }
    final pin = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${employee.name} manager'),
        content: TextField(
          controller: pin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '4-digit manager PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!RegExp(r'^\d{4}$').hasMatch(pin.text.trim())) {
      showMessage(context, 'Enter a 4-digit PIN', error: true);
      return;
    }
    try {
      await widget.repository.setEmployeeManager(
        employeeId: employee.id,
        isManager: true,
        pin: pin.text.trim(),
      );
      if (mounted) {
        showMessage(context, '${employee.name} is now a manager');
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is OnlineFailure
              ? error.message
              : 'Could not update manager access.',
          error: true,
        );
      }
    } finally {
      pin.dispose();
    }
  }

  Widget _employee(SalonStaff employee) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0F5DE),
      child: Icon(
        employee.isManager ? Icons.admin_panel_settings_outlined : Icons.person_outline,
      ),
    ),
    title: Text(
      employee.isManager ? '${employee.name} · Manager' : employee.name,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      employee.isWorking
          ? 'Working · active contract'
          : 'Joined · contract not set',
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'contract') {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ContractsScreen(
                repository: widget.repository,
                employee: employee,
              ),
            ),
          );
          if (mounted) _refresh();
        } else if (value == 'manager') {
          await _setManager(employee);
        } else if (value == 'qr' && employee.isWorking) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(employee.name),
              content: PublicQr(
                destination: QrDestination('barber', employee.id),
                label: 'Customer barber QR',
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'contract', child: Text('Contracts')),
        PopupMenuItem(
          value: 'manager',
          child: Text(
            employee.isManager ? 'Remove manager' : 'Make manager',
          ),
        ),
        if (employee.isWorking)
          const PopupMenuItem(value: 'qr', child: Text('Barber QR')),
      ],
    ),
    onTap: () async {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ContractsScreen(
            repository: widget.repository,
            employee: employee,
          ),
        ),
      );
      if (mounted) _refresh();
    },
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Employees',
    actions: [
      IconButton(
        tooltip: 'Refresh employees',
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
          final employees = staff
              .where((e) => e.joinStatus == 'accepted')
              .toList();
          final requests = _requests ?? pending.isNotEmpty;
          return AbsorbPointer(
            absorbing: _reviewing != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text('Requests (${pending.length})'),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Employees (${employees.length})'),
                    ),
                  ],
                  selected: {requests},
                  onSelectionChanged: (value) =>
                      setState(() => _requests = value.first),
                ),
                if (requests) ...[
                  if (pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No pending join requests.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...pending.map(_requestCard),
                ] else ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Add employee',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If they are not on TrimMatrix yet, add CNIC, phone and email. '
                    'They will see a join offer after installing the business app and completing their profile.',
                    style: TextStyle(color: Color(0xFF718094), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full name (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cnic,
                    keyboardType: TextInputType.number,
                    maxLength: 13,
                    decoration: InputDecoration(
                      labelText: 'CNIC (13 digits)',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '03127712502',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActionButton(
                    label: 'Invite by CNIC & email',
                    icon: Icons.person_add_outlined,
                    style: FilledButton.styleFrom(shape: _shape),
                    onPressed: () async {
                      if (!RegExp(r'^\d{13}$').hasMatch(_cnic.text.trim())) {
                        showMessage(
                          context,
                          'Enter a valid 13-digit CNIC',
                          error: true,
                        );
                        return;
                      }
                      if (!_email.text.contains('@')) {
                        showMessage(context, 'Enter a valid email', error: true);
                        return;
                      }
                      try {
                        await widget.repository.inviteEmployeeByIdentity(
                          businessId: widget.businessId,
                          cnic: _cnic.text,
                          phone: _phone.text,
                          email: _email.text,
                          name: _name.text,
                        );
                        await _syncLocalBillingStaff();
                        if (mounted) {
                          for (final c in [_name, _cnic, _phone, _email]) {
                            c.clear();
                          }
                          showMessage(
                            context,
                            'Invite saved. They can join after completing their profile.',
                          );
                          _refresh();
                        }
                      } catch (error) {
                        if (mounted) {
                          showMessage(
                            context,
                            error is OnlineFailure
                                ? error.message
                                : 'Could not add this employee. Try again.',
                            error: true,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Or paste existing profile code',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActionButton(
                    label: 'Invite by profile code',
                    icon: Icons.badge_outlined,
                    style: FilledButton.styleFrom(shape: _shape),
                    onPressed: () async {
                      if (!RegExp(
                        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                      ).hasMatch(_code.text.trim())) {
                        showMessage(
                          context,
                          'Paste a valid profile code',
                          error: true,
                        );
                        return;
                      }
                      try {
                        await widget.repository.inviteEmployee(
                          widget.businessId,
                          _code.text,
                        );
                        await _syncLocalBillingStaff();
                        if (mounted) {
                          _code.clear();
                          showMessage(context, 'Employee added to your salon');
                          _refresh();
                        }
                      } catch (error) {
                        if (mounted) {
                          showMessage(
                            context,
                            error is OnlineFailure
                                ? error.message
                                : 'Could not add this employee. Try again.',
                            error: true,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (employees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No employees yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...employees.map(_employee),
                ],
              ],
            ),
          );
        },
      ),
    ],
  );
}
