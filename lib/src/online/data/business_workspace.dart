import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../domain/online_models.dart';
import '../domain/online_repository.dart';

/// Every connected salon uses separate boxes, including on shared devices.
/// The journal survives process termination and ambiguous network responses.
class BusinessWorkspace extends ChangeNotifier {
  BusinessWorkspace._(
    this.repository,
    this.business,
    this.account,
    this.maps,
    this.phones,
    this.settings,
    this.journal,
  );
  final OnlineRepository repository;
  final SalonBusiness business;
  final OnlineAccount account;
  final Map<String, Box<Map>> maps;
  final Box<String> phones;
  final Box<dynamic> settings;
  final Box<dynamic> journal;
  bool busy = false, conflict = false, inPos = false;
  String status = 'Stored on this device';
  Timer? _timer;
  bool _disposed = false;
  static const collections = [
    'bills',
    'contacts',
    'employees',
    'expenses',
    'payouts',
    'services',
    'categories',
  ];

  static Future<BusinessWorkspace> open(
    OnlineRepository repository,
    SalonBusiness business,
    OnlineAccount account, {
    bool initializeHive = true,
  }) async {
    if (initializeHive) {
      await Hive.initFlutter();
    }
    final prefix = 'online_${account.id}_${business.id}';
    final maps = <String, Box<Map>>{};
    for (final name in collections) {
      maps[name] = await Hive.openBox<Map>('${prefix}_$name');
    }
    final workspace = BusinessWorkspace._(
      repository,
      business,
      account,
      maps,
      await Hive.openBox<String>('${prefix}_phones'),
      await Hive.openBox<dynamic>('${prefix}_settings'),
      await Hive.openBox<dynamic>('${prefix}_sync'),
    );
    final recovery = workspace.journal.get('applying');
    if (recovery != null) {
      await workspace._apply(Map<String, dynamic>.from(recovery as Map));
    }
    await workspace.ensureBusinessDefaults();
    await workspace.syncOnlineTeam();
    workspace._timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => workspace.synchronize(),
    );
    return workspace;
  }

  /// Seeds empty rate list / settings in DB, then mirrors tax, currency,
  /// expense types and payment accounts into this workspace's Hive settings.
  Future<BusinessSettings?> ensureBusinessDefaults() async {
    if (_disposed) return null;
    try {
      await repository.ensureBusinessServices(business.id);
      final remote = await repository.getBusinessSettings(business.id);
      await settings.put('tax_rate', remote.taxRate);
      await settings.put('currency_code', remote.currencyCode);
      // Customs only — system defaults live in SettingsStore / DB catalog.
      const defaultExpenses = {
        'utilities',
        'supplies',
        'maintenance',
        'tea/coffee',
        'rent',
        'salary advance',
        'marketing',
        'transport',
        'cleaning',
        'miscellaneous',
      };
      const defaultPayments = {
        'cash — counter',
        'easy — business',
        'card — pos',
        'online — bank transfer',
        'jazzcash — business',
      };
      final accountKey =
          'payment_accounts.v1.${account.id}';
      final expenseKey = 'expense_types.v1.${account.id}';
      await settings.put(
        expenseKey,
        remote.expenseTypes
            .where((e) => !defaultExpenses.contains(e.toLowerCase()))
            .toList(),
      );
      await settings.put(
        accountKey,
        remote.paymentAccounts
            .where((e) => !defaultPayments.contains(e.toLowerCase()))
            .toList(),
      );
      return remote;
    } catch (_) {
      // Offline / older schema: keep local Hive defaults (17 / PKR / in-app lists).
      if (settings.get('tax_rate') == null) {
        await settings.put('tax_rate', 17.0);
      }
      if (settings.get('currency_code') == null) {
        await settings.put('currency_code', 'PKR');
      }
      return null;
    }
  }

  /// Copies accepted online staff into the local employees box used by billing.
  Future<void> syncOnlineTeam() async {
    if (_disposed) return;
    final List<SalonStaff> team;
    try {
      team = await repository.team(business.id);
    } catch (_) {
      return;
    }
    final box = maps['employees'];
    if (box == null) return;
    final accepted = team.where((e) => e.joinStatus == 'accepted').toList();
    final acceptedIds = accepted.map((e) => e.id).toSet();
    for (final member in accepted) {
      final parts = member.name.trim().split(RegExp(r'\s+'));
      final first = parts.isEmpty || parts.first.isEmpty ? 'Staff' : parts.first;
      final last = parts.length <= 1 ? '' : parts.sublist(1).join(' ');
      final existing = box.get(member.id);
      if (existing == null) {
        await box.put(member.id, <String, dynamic>{
          'id': member.id,
          'firstName': first,
          'lastName': last,
          'phoneNumber': '',
          'cnicNumber': '',
          'homeAddress': '',
          'isActive': true,
          'isManager': false,
          'onlineSynced': true,
          'commission': '',
          'basicSalary': '',
          'employeeType': 'General',
        });
      } else {
        final map = Map<String, dynamic>.from(existing);
        map['firstName'] = first;
        map['lastName'] = last;
        map['isActive'] = true;
        map['onlineSynced'] = true;
        await box.put(member.id, map);
      }
    }
    for (final key in box.keys.toList()) {
      final row = box.get(key);
      if (row == null) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['onlineSynced'] == true &&
          !acceptedIds.contains(key.toString())) {
        map['isActive'] = false;
        await box.put(key, map);
      }
    }
    if (!_disposed) notifyListeners();
  }

  Map<String, dynamic> snapshot() => {
    for (final entry in maps.entries) entry.key: _boxData(entry.value),
    'phones': _boxData(phones),
    'settings': _boxData(settings),
  };
  Map<String, dynamic> _boxData(Box box) {
    final keys = box.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: box.get(key)};
  }

  Map<String, dynamic> get _base => Map<String, dynamic>.from(
    journal.get(
          'base',
          defaultValue: {
            for (final name in [...collections, 'phones', 'settings'])
              name: <String, dynamic>{},
          },
        )
        as Map,
  );
  int get _revision => journal.get('revision', defaultValue: 0) as int;
  bool _same(Object? a, Object? b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));
  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  Future<void> _apply(Map<String, dynamic> remote) async {
    // Persist the intended replacement first so a crash midway can be recovered.
    await journal.put('applying', remote);
    final payload = Map<String, dynamic>.from(remote['payload'] as Map);
    for (final name in collections) {
      final rows = Map<String, dynamic>.from(payload[name] as Map? ?? {});
      final box = maps[name]!;
      await box.deleteAll(
        box.keys.where((key) => !rows.containsKey(key)).toList(),
      );
      await box.putAll(
        rows.map((key, value) => MapEntry(key, Map.from(value as Map))),
      );
    }
    final phoneRows = Map<String, String>.from(payload['phones'] as Map? ?? {});
    await phones.deleteAll(
      phones.keys.where((key) => !phoneRows.containsKey(key)).toList(),
    );
    await phones.putAll(phoneRows);
    final settingRows = Map<String, dynamic>.from(
      payload['settings'] as Map? ?? {},
    );
    await settings.deleteAll(
      settings.keys.where((key) => !settingRows.containsKey(key)).toList(),
    );
    await settings.putAll(settingRows);
    await journal.putAll({'base': snapshot(), 'revision': remote['revision']});
    await journal.delete('applying');
  }

  Future<bool> _send(Map<String, dynamic> pending) async {
    if (utf8.encode(jsonEncode(pending['payload'])).length > 19 * 1024 * 1024) {
      throw const OnlineFailure(
        'This workspace is too large to sync (19 MB limit). Local records are safe.',
      );
    }
    final result = await repository.syncBusiness(
      business.id,
      pending['revision'] as int,
      pending['operation'] as String,
      Map<String, dynamic>.from(pending['payload'] as Map),
    );
    if (result['conflict'] == true) {
      conflict = true;
      status =
          'Another device changed this salon. Resolve the conflict before syncing.';
      return false;
    }
    await journal.putAll({
      'base': pending['payload'],
      'revision': result['revision'],
    });
    await journal.delete('pending');
    return true;
  }

  Future<void> synchronize() async {
    if (busy || conflict || _disposed || repository.userId != account.id) {
      return;
    }
    busy = true;
    _notify();
    try {
      final pending = journal.get('pending');
      if (pending != null &&
          !await _send(Map<String, dynamic>.from(pending as Map))) {
        return;
      }
      final remote = await repository.businessSnapshot(business.id);
      if (_disposed || repository.userId != account.id) return;
      final local = snapshot();
      final changed = !_same(local, _base);
      if ((remote?['revision'] ?? 0) != _revision) {
        if (changed) {
          conflict = true;
          status =
              'Another device changed this salon. Choose which version to keep.';
          return;
        }
        if (inPos) {
          status = 'Cloud changes available. Close the workspace to load them.';
          return;
        }
        if (remote != null) await _apply(remote);
        // Cloud payload may not include online memberships — re-merge them.
        await syncOnlineTeam();
      } else if (changed) {
        final operation = {
          'revision': _revision,
          'operation': const Uuid().v4(),
          'payload': local,
        };
        await journal.put('pending', operation);
        if (!await _send(operation)) return;
      } else {
        await syncOnlineTeam();
      }
      status =
          'Synced · ${DateTime.now().toLocal().toString().substring(0, 19)}';
    } on OnlineFailure catch (error) {
      status = error.message;
    } on PostgrestException {
      status =
          'Cloud rejected this update. Local records are safe. Check your account access and database setup.';
    } catch (_) {
      status =
          'Saved on this device. Cloud sync unavailable; retry when connected.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> resolve({required bool keepLocal}) async {
    if (busy || inPos) return;
    busy = true;
    _notify();
    try {
      final remote = await repository.businessSnapshot(business.id);
      if (remote == null) {
        throw const OnlineFailure('Cloud version is unavailable. Retry later.');
      }
      // Retain both versions locally before resolving; never discard the only copy.
      await journal.put(
        'conflict_backup_${DateTime.now().microsecondsSinceEpoch}',
        {'local': snapshot(), 'cloud': remote},
      );
      if (keepLocal) {
        await journal.putAll({
          'base': remote['payload'],
          'revision': remote['revision'],
        });
      } else {
        await _apply(remote);
      }
      await journal.delete('pending');
      conflict = false;
    } finally {
      busy = false;
      _notify();
    }
    await synchronize();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
