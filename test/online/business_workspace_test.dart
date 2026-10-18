import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'fake_online_repository.dart';

class SyncRepository extends FakeOnlineRepository {
  Map<String, dynamic>? remote;
  bool offline = false, loseResponse = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> businessSnapshot(String businessId) async {
    if (offline) throw const SocketException('Offline');
    return remote;
  }

  @override
  Future<Map<String, dynamic>> syncBusiness(
    String businessId,
    int revision,
    String operation,
    Map<String, dynamic> data,
  ) async {
    if (offline) throw const SocketException('Offline');
    if (remote?['operation'] == operation) {
      return {'conflict': false, 'revision': remote!['revision']};
    }
    if ((remote?['revision'] ?? 0) != revision) {
      return {'conflict': true, 'revision': remote!['revision']};
    }
    writes++;
    remote = {
      'revision': revision + 1,
      'operation': operation,
      'payload': jsonDecode(jsonEncode(data)),
    };
    if (loseResponse) {
      loseResponse = false;
      throw TimeoutException('Response lost');
    }
    return {'conflict': false, 'revision': revision + 1};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SyncRepository repository;
  final opened = <BusinessWorkspace>[];
  const account = OnlineAccount(id: 'owner', name: 'Owner');
  Future<BusinessWorkspace> open([String id = 'salon']) async {
    final workspace = await BusinessWorkspace.open(
      repository,
      SalonBusiness(
        id: id,
        name: id,
        phone: '03000000000',
        type: 'salon',
        city: 'Lahore',
        area: 'Area',
        address: 'Address',
        isActive: true,
      ),
      account,
      initializeHive: false,
    );
    opened.add(workspace);
    return workspace;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('salon_sync_test_');
    Hive.init(directory.path);
    repository = SyncRepository()..userId = 'owner';
  });
  tearDown(() async {
    for (final workspace in opened) {
      workspace.dispose();
    }
    opened.clear();
    await Hive.close();
    await directory.delete(recursive: true);
    await repository.events.close();
  });
  test('offline records survive reopening and later synchronize', () async {
    var workspace = await open();
    repository.offline = true;
    await workspace.maps['bills']!.put('bill1', {'total': 500});
    await workspace.synchronize();
    expect(repository.remote, isNull);
    workspace.dispose();
    opened.remove(workspace);
    workspace = await open();
    expect(workspace.maps['bills']!.get('bill1')?['total'], 500);
    repository.offline = false;
    await workspace.synchronize();
    expect(repository.remote?['payload']['bills']['bill1']['total'], 500);
    expect(workspace.journal.get('pending'), isNull);
  });
  test(
    'lost response retries the same operation without duplicate writes',
    () async {
      final workspace = await open();
      await workspace.maps['bills']!.put('bill1', {'total': 100});
      repository.loseResponse = true;
      await workspace.synchronize();
      expect(workspace.journal.get('pending'), isNotNull);
      await workspace.maps['bills']!.put('bill2', {'total': 200});
      await workspace.synchronize();
      expect(repository.writes, 2);
      expect(repository.remote?['payload']['bills'].length, 2);
      expect(workspace.journal.get('pending'), isNull);
    },
  );
  test(
    'conflicts preserve local data and back up both versions before resolution',
    () async {
      final workspace = await open();
      await workspace.maps['bills']!.put('bill1', {'total': 100});
      await workspace.synchronize();
      repository.remote!['revision'] = 2;
      repository.remote!['payload']['bills']['bill1'] = {'total': 300};
      await workspace.maps['bills']!.put('bill1', {'total': 200});
      await workspace.synchronize();
      expect(workspace.conflict, isTrue);
      expect(workspace.maps['bills']!.get('bill1')?['total'], 200);
      await workspace.resolve(keepLocal: false);
      expect(workspace.maps['bills']!.get('bill1')?['total'], 300);
      expect(
        workspace.journal.keys.any(
          (key) => key.toString().startsWith('conflict_backup_'),
        ),
        isTrue,
      );
    },
  );
  test('different salons have isolated boxes and logout stops sync', () async {
    final first = await open('one');
    final second = await open('two');
    await first.maps['bills']!.put('private', {'total': 100});
    expect(second.maps['bills']!.isEmpty, isTrue);
    repository.userId = null;
    await first.synchronize();
    expect(repository.writes, 0);
  });
  test('cloud changes do not overwrite stores while POS is open', () async {
    final workspace = await open();
    await workspace.maps['bills']!.put('bill1', {'total': 100});
    await workspace.synchronize();
    repository.remote!['revision'] = 2;
    repository.remote!['payload']['bills']['bill1'] = {'total': 300};
    workspace.inPos = true;
    await workspace.synchronize();
    expect(workspace.maps['bills']!.get('bill1')?['total'], 100);
    workspace.inPos = false;
    await workspace.synchronize();
    expect(workspace.maps['bills']!.get('bill1')?['total'], 300);
  });
}
