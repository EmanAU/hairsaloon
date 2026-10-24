import 'package:flutter/material.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/services/toast_service.dart';
import '../domain/online_models.dart';
import 'employee_home.dart';
import 'online_session.dart';
import 'workspace_screen.dart';
import 'widgets/online_widgets.dart';

/// A manager remains an employee and explicitly chooses which workspace to open.
class ManagerEntry extends StatefulWidget {
  const ManagerEntry({super.key, required this.session});
  final OnlineSession session;
  @override
  State<ManagerEntry> createState() => _ManagerEntryState();
}

class _ManagerEntryState extends State<ManagerEntry> {
  late Future<List<ManagerBusiness>> _businesses = widget.session.repository
      .myManagerBusinesses();
  bool _employee = false;

  Future<void> _openShop(ManagerBusiness shop) async {
    final pin = await showAppTextInputSheet(
      context: context,
      title: 'Manager access',
      label: '4-digit manager PIN',
      subtitle: shop.businessName,
      keyboardType: TextInputType.number,
      maxLength: 4,
      confirmLabel: 'Open shop',
      validator: (value) => RegExp(r'^\d{4}$').hasMatch(value)
          ? null
          : 'Enter the 4-digit PIN from the owner',
    );
    if (pin == null || !mounted) return;
    if (!await widget.session.repository.verifyManagerPin(
      shop.businessId,
      pin,
    )) {
      if (mounted) {
        ToastService.error(
          'Incorrect PIN or manager access has been removed.',
          context,
        );
      }
      return;
    }
    final business = await widget.session.repository.findBusiness(
      shop.businessId,
    );
    if (!mounted) return;
    if (business == null || !business.isActive) {
      throw const OnlineFailure('This shop is not available.');
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkspaceScreen(
          repository: widget.session.repository,
          business: business,
          asManager: true,
        ),
      ),
    );
    if (mounted) {
      setState(
        () => _businesses = widget.session.repository.myManagerBusinesses(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => RemoteContent<List<ManagerBusiness>>(
    future: _businesses,
    onRetry: () => setState(
      () => _businesses = widget.session.repository.myManagerBusinesses(),
    ),
    builder: (businesses) {
      if (businesses.isEmpty || _employee) {
        return EmployeeHome(
          session: widget.session,
          onSignOut: widget.session.repository.signOut,
          onSwitchWorkspace: businesses.isEmpty
              ? null
              : () => setState(() => _employee = false),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Choose your workspace'),
          actions: [
            IconButton(
              tooltip: 'Refresh manager access',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(
                () => _businesses = widget.session.repository
                    .myManagerBusinesses(),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome, ${widget.session.workspace!.account.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can use your employee dashboard or manage your assigned shop.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Employee dashboard'),
                subtitle: const Text('My work, earnings and personal profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _employee = true),
              ),
            ),
            for (final shop in businesses)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        shop.businessName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('Assigned shop manager · PIN required'),
                      const SizedBox(height: 12),
                      ActionButton(
                        label: 'Open shop as manager',
                        icon: Icons.storefront_outlined,
                        onPressed: () => _openShop(shop),
                      ),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: widget.session.repository.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
    },
  );
}
