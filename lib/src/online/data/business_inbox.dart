import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

/// Shared by the bell and join queue; receipts belong to this account and salon.
class BusinessInbox extends ChangeNotifier {
  BusinessInbox({
    required this.repository,
    required this.businessId,
    required String accountId,
  }) : _receiptKey = 'business_inbox.v1.$accountId.$businessId';

  final OnlineRepository repository;
  final String businessId;
  final String _receiptKey;
  List<SalonStaff> _pending = const [];
  List<SalonStaff> get pending => _pending;
  List<SalonStaff> _unread = const [];
  List<SalonStaff> get unread => _unread;
  final Set<String> _read = {};
  SharedPreferences? _preferences;
  Timer? _poll;
  StreamSubscription<void>? _subscription;
  Future<void>? _loading;
  bool _again = false, _disposed = false, _started = false;
  bool loaded = false;
  String? error;
  int _epoch = 0;

  String noticeId(SalonStaff request) =>
      '${request.id}:${request.requestedAt?.toUtc().toIso8601String() ?? 'initial'}';

  void start() {
    if (_started || _disposed) return;
    _started = true;
    final source = repository;
    if (source is BusinessActivitySource) {
      _subscription = (source as BusinessActivitySource)
          .businessActivityChanges(businessId)
          .listen((_) => unawaited(refresh()), onError: (Object _) {});
    }
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_loading != null) {
      _again = true;
      return _loading!;
    }
    return _loading = _reload().whenComplete(() => _loading = null);
  }

  Future<void> _reload() async {
    do {
      _again = false;
      final epoch = _epoch;
      try {
        if (_preferences == null) {
          _preferences = await SharedPreferences.getInstance();
          _read.addAll(_preferences!.getStringList(_receiptKey) ?? []);
        }
        final team = await repository.team(businessId);
        if (_disposed) return;
        if (epoch != _epoch) {
          _again = true;
          continue;
        }
        _pending = List.unmodifiable(
          team.where((row) => row.joinStatus == 'pending'),
        );
        loaded = true;
        error = null;
        _publish();
      } catch (_) {
        if (_disposed) return;
        error = 'Could not load join requests. Please try again.';
        notifyListeners();
      }
    } while (_again && !_disposed);
  }

  void _publish() {
    _unread = List.unmodifiable(
      _pending.where((row) => !_read.contains(noticeId(row))),
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> markRead(SalonStaff request) async {
    _read.add(noticeId(request));
    _publish();
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.setStringList(_receiptKey, _read.toList());
  }

  Future<void> markAllRead() async {
    for (final request in _pending) {
      _read.add(noticeId(request));
    }
    _publish();
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.setStringList(_receiptKey, _read.toList());
  }

  /// Called only after the server accepts the review, before any follow-up sync.
  void resolve(String employeeId) {
    _epoch++;
    _pending = List.unmodifiable(_pending.where((row) => row.id != employeeId));
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
