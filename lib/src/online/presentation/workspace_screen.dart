import 'dart:async';
import 'package:flutter/material.dart';
import '../../app.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'online_dashboard_tools.dart';
import 'widgets/online_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.repository,
    required this.business,
    this.onClose,
    this.asManager = false,
  });
  final OnlineRepository repository;
  final SalonBusiness business;
  final VoidCallback? onClose;
  final bool asManager;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  BusinessWorkspace? _workspace;
  late Future<BusinessWorkspace> _ready = _open();
  bool _showSync = false;

  Future<BusinessWorkspace> _open() async {
    final account = await widget.repository.loadWorkspace();
    final businesses = account.businesses.where(
      (business) => business.id == widget.business.id,
    );
    SalonBusiness? selected = businesses.isEmpty ? null : businesses.first;
    if (widget.asManager) {
      final assigned = await widget.repository.myManagerBusinesses();
      if (!assigned.any((shop) => shop.businessId == widget.business.id)) {
        throw const OnlineFailure('Manager access is no longer available.');
      }
      selected = await widget.repository.findBusiness(widget.business.id);
    }
    if (selected == null || !selected.isActive) {
      throw const OnlineFailure('Business approval is required.');
    }
    final workspace = await BusinessWorkspace.open(
      widget.repository,
      selected,
      account.account,
      personalProfile: account.profile,
    );
    if (!mounted) {
      workspace.dispose();
      throw StateError('Workspace closed');
    }
    _workspace = workspace;
    await workspace.synchronize();
    await workspace.syncOnlineTeam();
    if (!mounted) {
      workspace.dispose();
      throw StateError('Workspace closed');
    }
    _showSync = workspace.conflict;
    workspace.inPos = !_showSync;
    return workspace;
  }

  Future<void> _reload() async {
    final current = _workspace;
    if (current != null) {
      current.inPos = false;
      await current.synchronize();
      current.dispose();
    }
    if (!mounted) return;
    setState(() {
      _workspace = null;
      _ready = _open();
    });
  }

  void _dashboard(BusinessWorkspace workspace) {
    if (workspace.busy) return;
    setState(() {
      workspace.inPos = true;
      _showSync = false;
    });
  }

  @override
  void dispose() {
    _workspace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BusinessWorkspace>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return OnlinePage(
          title: 'Business workspace',
          children: [
            Text(
              snapshot.error is OnlineFailure
                  ? (snapshot.error as OnlineFailure).message
                  : 'Could not open your business. Please retry.',
            ),
            ActionButton(label: 'Retry', onPressed: _reload),
          ],
        );
      }
      final workspace = snapshot.data!;
      if (_showSync) return _syncPage(workspace);
      return BusinessCombApp(
        workspace: workspace,
        hosted: true,
        onCloseWorkspace:
            widget.onClose ?? () => Navigator.of(context).maybePop(),
        onLogOut: widget.repository.signOut,
        onGoOnline: () {
          unawaited(workspace.synchronize());
        },
        dashboardExtras: (_) => OnlineDashboardTools(
          workspace: workspace,
          onClose: widget.onClose ?? () => Navigator.of(context).maybePop(),
          onSync: () => setState(() {
            workspace.inPos = false;
            _showSync = true;
          }),
        ),
      );
    },
  );

  Widget _syncPage(BusinessWorkspace workspace) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _dashboard(workspace);
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Sync status'),
        leading: IconButton(
          tooltip: 'Back to dashboard',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _dashboard(workspace),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: workspace,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(workspace.status),
                if (workspace.busy) const LinearProgressIndicator(),
                ActionButton(
                  label: 'Sync now',
                  icon: Icons.sync,
                  onPressed: workspace.synchronize,
                ),
                if (workspace.conflict) ...[
                  const Text(
                    'Choose which version to keep. Both versions are backed up on this device.',
                  ),
                  ActionButton(
                    label: 'Keep this device version',
                    onPressed: () => workspace.resolve(keepLocal: true),
                  ),
                  ActionButton(
                    label: 'Use cloud version',
                    onPressed: () => workspace.resolve(keepLocal: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
