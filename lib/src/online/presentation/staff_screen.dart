import 'package:flutter/material.dart';
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
  });
  final OnlineRepository repository;
  final String businessId;
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<List<SalonStaff>> _staff = widget.repository.staff(
    widget.businessId,
  );
  final _code = TextEditingController();
  void _refresh() =>
      setState(() => _staff = widget.repository.staff(widget.businessId));
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Employees',
    actions: [
      IconButton(
        tooltip: 'Refresh employees',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      const Text(
        'Invite a barber using their profile code, or open an existing membership to manage contracts.',
      ),
      TextField(
        controller: _code,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Employee profile code'),
      ),
      ActionButton(
        label: 'Invite employee',
        icon: Icons.person_add_outlined,
        onPressed: () async {
          if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(_code.text.trim())) {
            showMessage(context, 'Paste a valid profile code');
            return;
          }
          await widget.repository.inviteEmployee(widget.businessId, _code.text);
          if (mounted) {
            _code.clear();
            _refresh();
          }
        },
      ),
      RemoteContent<List<SalonStaff>>(
        future: _staff,
        onRetry: _refresh,
        builder: (staff) => Column(
          children: [
            if (staff.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No employee requests yet.'),
              ),
            for (final employee in staff)
              Card(
                child: ListTile(
                  title: Text(employee.name),
                  subtitle: Text(
                    employee.isWorking
                        ? 'Working · active contract'
                        : 'No current active contract',
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
                                destination: QrDestination(
                                  'barber',
                                  employee.id,
                                ),
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
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
