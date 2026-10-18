import 'package:flutter/material.dart';
import '../../app.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.repository,
    required this.business,
  });
  final OnlineRepository repository;
  final SalonBusiness business;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  BusinessWorkspace? _workspace;
  late Future<BusinessWorkspace> _ready = _open();
  Future<BusinessWorkspace> _open() async {
    final account = (await widget.repository.loadWorkspace()).account;
    final workspace = await BusinessWorkspace.open(
      widget.repository,
      widget.business,
      account,
    );
    if (!mounted) {
      workspace.dispose();
      throw StateError('Workspace closed');
    }
    _workspace = workspace;
    await workspace.synchronize();
    return workspace;
  }

  @override
  void dispose() {
    _workspace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: '${widget.business.name} workspace',
    children: [
      RemoteContent(
        future: _ready,
        onRetry: () {
          _workspace?.dispose();
          _workspace = null;
          setState(() => _ready = _open());
        },
        builder: (workspace) => ListenableBuilder(
          listenable: workspace,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bills, customers, expenses, payouts, local staff, services and settings are stored separately for this salon. Changes sync every 30 seconds while this workspace is open.',
              ),
              const SizedBox(height: 16),
              Text(workspace.status),
              if (workspace.busy) const LinearProgressIndicator(),
              ActionButton(
                label: 'Sync now',
                icon: Icons.sync,
                onPressed: workspace.synchronize,
              ),
              if (workspace.conflict) ...[
                const Text(
                  'Both versions are backed up on this device before your choice is applied.',
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
              ActionButton(
                label: 'Open business workspace',
                icon: Icons.point_of_sale,
                onPressed: () async {
                  if (workspace.busy) return;
                  workspace.inPos = true;
                  try {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: SafeArea(
                            child: Column(
                              children: [
                                Material(
                                  child: ListTile(
                                    title: Text(widget.business.name),
                                    subtitle: ListenableBuilder(
                                      listenable: workspace,
                                      builder: (_, _) => Text(workspace.status),
                                    ),
                                    leading: IconButton(
                                      tooltip: 'Close workspace',
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: BusinessCombApp(workspace: workspace),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } finally {
                    workspace.inPos = false;
                  }
                  await workspace.synchronize();
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
