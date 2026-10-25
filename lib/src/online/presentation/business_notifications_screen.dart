import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../data/business_inbox.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import 'join_requests_screen.dart';

class BusinessNotificationBell extends StatelessWidget {
  const BusinessNotificationBell({super.key, required this.workspace});
  final BusinessWorkspace workspace;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: workspace.inbox,
    child: Builder(
      builder: (context) {
        final count = context.select<BusinessInbox, int>(
          (inbox) => inbox.unread.length,
        );
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BusinessNotificationsScreen(workspace: workspace),
            ),
          ),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(
              CupertinoIcons.bell,
              color: AppColors.homeInk,
              size: 23,
            ),
          ),
        );
      },
    ),
  );
}

class BusinessNotificationsScreen extends StatelessWidget {
  const BusinessNotificationsScreen({super.key, required this.workspace});
  final BusinessWorkspace workspace;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: workspace.inbox,
    child: Builder(
      builder: (context) {
        final state = context
            .select<
              BusinessInbox,
              ({List<SalonStaff> notices, bool loaded, String? error})
            >(
              (inbox) => (
                notices: inbox.unread,
                loaded: inbox.loaded,
                error: inbox.error,
              ),
            );
        final notices = state.notices;
        return Scaffold(
          backgroundColor: AppColors.homeCanvas,
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: AppColors.homeCanvas,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (notices.isNotEmpty)
                TextButton(
                  onPressed: workspace.inbox.markAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: workspace.inbox.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Salon updates',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.homeInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New join requests appear here. Read updates clear from your inbox.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!state.loaded && state.error == null)
                      const Center(child: CircularProgressIndicator()),
                    if (state.error != null)
                      TextButton.icon(
                        onPressed: workspace.inbox.refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(state.error!),
                      ),
                    if (state.loaded && notices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.homeBorder),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              CupertinoIcons.bell,
                              size: 32,
                              color: AppColors.homeOlive,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'You’re all caught up',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'New updates will appear automatically.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    for (final request in notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.homeBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.homeSage,
                              child: Icon(
                                Icons.person_add_alt_outlined,
                                color: AppColors.homeOlive,
                              ),
                            ),
                            title: const Text(
                              'New join request',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${request.name} wants to join ${workspace.business.name}.\nTap to review request.',
                              style: const TextStyle(height: 1.5),
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Mark as read',
                              onPressed: () =>
                                  workspace.inbox.markRead(request),
                              icon: const Icon(
                                Icons.done,
                                color: AppColors.homeOlive,
                              ),
                            ),
                            onTap: () async {
                              await workspace.inbox.markRead(request);
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => JoinRequestsScreen(
                                    repository: workspace.repository,
                                    businessId: workspace.business.id,
                                    workspace: workspace,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
