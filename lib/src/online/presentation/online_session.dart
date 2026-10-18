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
  bool _disposed = false;
  int _generation = 0;

  bool get signedIn => repository.userId != null;

  Future<void> reload() async {
    if (_disposed) return;
    final generation = ++_generation;
    final id = repository.userId;
    workspace = null;
    error = null;
    loading = id != null;
    notifyListeners();
    if (id == null) return;
    try {
      final result = await repository.loadWorkspace();
      if (!_disposed && generation == _generation && repository.userId == id) {
        workspace = result;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Could not load your account. Check your connection and retry.';
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
