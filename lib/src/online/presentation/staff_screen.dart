import 'package:flutter/material.dart';
import '../data/business_workspace.dart';
import '../domain/online_repository.dart';
import 'join_requests_screen.dart';
import 'team_contracts_screen.dart';

/// Compatibility entry: join requests or team contracts (no invite forms).
class StaffScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (showRequests ?? false) {
      return JoinRequestsScreen(
        repository: repository,
        businessId: businessId,
        workspace: workspace,
      );
    }
    return TeamContractsScreen(
      repository: repository,
      businessId: businessId,
    );
  }
}
