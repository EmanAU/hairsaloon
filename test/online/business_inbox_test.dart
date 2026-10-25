import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/online/data/business_inbox.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'fake_online_repository.dart';

SalonStaff request(String id, {DateTime? at}) => SalonStaff(
  id: id,
  name: id,
  isWorking: false,
  joinStatus: 'pending',
  requestedAt: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'live events update counts; reading persists and leaves the queue pending',
    () async {
      final repository = FakeOnlineRepository()..teamRows = [request('ali')];
      final inbox = BusinessInbox(
        repository: repository,
        businessId: 'salon',
        accountId: 'owner',
      );
      addTearDown(inbox.dispose);
      addTearDown(repository.activityEvents.close);
      inbox.start();
      await inbox.refresh();
      expect(inbox.unread.length, 1);
      await inbox.markRead(inbox.pending.single);
      expect(inbox.unread, isEmpty);
      expect(inbox.pending.length, 1);
      await inbox.refresh();
      expect(inbox.unread, isEmpty);
      final reopened = BusinessInbox(
        repository: repository,
        businessId: 'salon',
        accountId: 'owner',
      );
      addTearDown(reopened.dispose);
      await reopened.refresh();
      expect(reopened.unread, isEmpty);
      final other = BusinessInbox(
        repository: repository,
        businessId: 'other-salon',
        accountId: 'owner',
      );
      addTearDown(other.dispose);
      await other.refresh();
      expect(other.unread.length, 1);
      final otherAccount = BusinessInbox(
        repository: repository,
        businessId: 'salon',
        accountId: 'other-owner',
      );
      addTearDown(otherAccount.dispose);
      await otherAccount.refresh();
      expect(otherAccount.unread.length, 1);

      final updated = Completer<void>();
      inbox.addListener(() {
        if (inbox.pending.length == 2 && !updated.isCompleted) {
          updated.complete();
        }
      });
      repository.teamRows = [request('ali'), request('bilal')];
      repository.activityEvents.add(null);
      await updated.future.timeout(const Duration(seconds: 2));
      expect(inbox.unread.map((row) => row.id), ['bilal']);
      inbox.resolve('bilal');
      expect(inbox.pending.length, 1);
      expect(inbox.unread, isEmpty);
    },
  );

  test(
    'a renewed request creates a fresh notification and handled requests disappear',
    () async {
      final repository = FakeOnlineRepository()
        ..teamRows = [request('ali', at: DateTime.utc(2026, 10, 25))];
      final inbox = BusinessInbox(
        repository: repository,
        businessId: 'salon',
        accountId: 'owner',
      );
      addTearDown(inbox.dispose);
      await inbox.refresh();
      await inbox.markAllRead();
      repository.teamRows = [];
      await inbox.refresh();
      expect(inbox.pending, isEmpty);
      repository.teamRows = [request('ali', at: DateTime.utc(2026, 10, 26))];
      await inbox.refresh();
      expect(inbox.unread.length, 1);
      repository.teamRows = [
        const SalonStaff(
          id: 'ali',
          name: 'Ali',
          isWorking: false,
          joinStatus: 'accepted',
        ),
      ];
      await inbox.refresh();
      expect(inbox.pending, isEmpty);
      expect(inbox.unread, isEmpty);
    },
  );

  test(
    'a late in-flight response cannot restore a completed request',
    () async {
      final repository = DelayedTeamRepository()..teamRows = [request('ali')];
      final inbox = BusinessInbox(
        repository: repository,
        businessId: 'salon',
        accountId: 'owner',
      );
      addTearDown(inbox.dispose);
      await inbox.refresh();
      final stale = Completer<List<SalonStaff>>();
      repository.next = stale.future;
      final refreshing = inbox.refresh();
      inbox.resolve('ali');
      repository.teamRows = [];
      stale.complete([request('ali')]);
      await refreshing;
      expect(inbox.pending, isEmpty);
      expect(inbox.unread, isEmpty);
    },
  );
}

class DelayedTeamRepository extends FakeOnlineRepository {
  Future<List<SalonStaff>>? next;
  @override
  Future<List<SalonStaff>> team(String businessId) {
    final response = next;
    next = null;
    return response ?? super.team(businessId);
  }
}
