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

  Widget _employee(SalonStaff employee) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: const CircleAvatar(
      backgroundColor: Color(0xFFF0F5DE),
      child: Icon(Icons.person_outline),
    ),
    title: Text(
      employee.name,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      employee.isWorking
          ? 'Working · active contract'
          : 'Joined · contract not set',
    ),
    trailing: employee.isWorking
        ? IconButton(
            tooltip: 'Barber customer QR',
            icon: const Icon(Icons.qr_code),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(employee.name),
                content: PublicQr(
                  destination: QrDestination('barber', employee.id),
                  label: 'Customer barber QR',
                ),
              ),
            ),
          )
        : const Icon(Icons.chevron_right),
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
                  TextField(
                    controller: _code,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Employee profile code',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActionButton(
                    label: 'Invite employee',
                    icon: Icons.person_add_outlined,
                    style: FilledButton.styleFrom(shape: _shape),
                    onPressed: () async {
                      if (!RegExp(
                        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                      ).hasMatch(_code.text.trim())) {
                        showMessage(context, 'Paste a valid profile code');
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
