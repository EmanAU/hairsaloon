import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

class OnlineSession extends ChangeNotifier {
  OnlineSession(this.repository) {
    _subscription = repository.authChanges.listen(
      (_) => reload(),
      onError: (Object error) {
        if (_disposed) return;
        this.error = 'Sign-in could not be completed. Please try again.';
        notifyListeners();
      },
    );
    unawaited(reload());
  }

  final OnlineRepository repository;
  late final StreamSubscription<String?> _subscription;
  OnlineWorkspace? workspace;
  String? error;
  bool loading = false;
  List<SalonJoinRequest> memberships = const [];
  List<PendingEmployeeInvite> invitations = const [];
  bool get hasEmployment => memberships.any((m) => m.status == 'accepted');
  bool _disposed = false;
  int _generation = 0;
  String? _workspaceUser;

  bool get signedIn => repository.userId != null;

  // Called only after the server confirms registration. A failed follow-up
  // refresh must not lose this business or send its owner back to setup.
  void rememberRegisteredBusiness(SalonBusiness business) {
    final current = workspace;
    if (_disposed || current == null || !signedIn) return;
    workspace = OnlineWorkspace(
      account: current.account,
      profile: current.profile,
      businesses: [
        ...current.businesses.where((item) => item.id != business.id),
        business,
      ],
    );
    _workspaceUser = repository.userId;
    notifyListeners();
  }

  Future<void> reload() async {
    if (_disposed) return;
    final generation = ++_generation;
    final id = repository.userId;
    final previous = _workspaceUser == id ? workspace : null;
    // Keep existing workspace on screen while refreshing — avoid sync/extra panels.
    if (previous == null) {
      workspace = null;
    }
    error = null;
    loading = id != null && previous == null;
    notifyListeners();
    if (id == null) {
      workspace = null;
      _workspaceUser = null;
      memberships = const [];
      invitations = const [];
      return;
    }
    try {
      final result = await repository.loadWorkspace();
      final roles = await repository.joinRequests();
      final pending = await repository.pendingInvitesForMe();
      if (!_disposed && generation == _generation && repository.userId == id) {
        memberships = roles;
        invitations = pending;
        // Keep just-registered (or cached) salons if the live fetch is empty/stale.
        workspace = previous == null
            ? result
            : OnlineWorkspace(
                account: result.account,
                profile: result.profile ?? previous.profile,
                businesses: {
                  for (final business in previous.businesses)
                    business.id: business,
                  for (final business in result.businesses)
                    business.id: business,
                }.values.toList(),
                isCached: result.isCached,
              );
        _workspaceUser = id;
        error = null;
      }
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        if (previous != null && repository.userId == id) {
          workspace = OnlineWorkspace(
            account: previous.account,
            profile: previous.profile,
            businesses: previous.businesses,
            isCached: true,
          );
          // Soft refresh failed but we still have a home — stay quiet.
          error = null;
        } else {
          error = failure is OnlineFailure
              ? failure.message
              : 'Could not open your account. Please retry.';
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
