import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/staff_screen.dart';
import 'package:hairsaloon/src/online/presentation/business_home.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'fake_online_repository.dart';
import 'workspace_test_environment.dart';

void main() {
  testWidgets('home badge refreshes when a join request arrives', (
    tester,
  ) async {
    await prepareOnlineWorkspace(tester);
    final repository = FakeOnlineRepository()..userId = 'owner';
    repository.workspace = OnlineWorkspace(
      account: const OnlineAccount(id: 'owner', name: 'Owner'),
      profile: PersonalProfile(
        code: 'permanent-code',
        phone: '+923001234567',
        cnic: '1234512345671',
        dateOfBirth: DateTime(1995, 1, 1),
        workStartedOn: DateTime(2015, 1, 1),
        photoPath: 'user/photo.jpg',
      ),
      businesses: const [
        SalonBusiness(
          id: 'salon',
          name: 'Test Salon',
          phone: '03127712502',
          type: 'Hair Salon',
          city: 'Lahore',
          area: 'Gulberg',
          address: 'Main Road',
          isActive: true,
        ),
      ],
    );
    addTearDown(repository.events.close);
    final session = OnlineSession(repository);
    await preopenOnlineWorkspace(tester, repository);
    addTearDown(session.dispose);
    await session.reload();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessHome(
          session: session,
          onSignOut: repository.signOut,
          onOpenOffline: () {},
        ),
      ),
    );
    await waitForOnlineDashboard(tester);
    expect(
      tester.widget<Badge>(find.byType(Badge).last).isLabelVisible,
      isFalse,
    );
    repository.teamRows = const [
      SalonStaff(
        id: 'employee',
        name: 'Ali',
        isWorking: false,
        joinStatus: 'pending',
      ),
    ];
    repository.activityEvents.add(null);
    await tester.pump();
    await tester.pumpAndSettle();
    final badge = tester.widget<Badge>(find.byType(Badge).last);
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label as Text).data, '1');
    await tester.ensureVisible(find.text('Join Requests'));
    await tester.tap(find.text('Join Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await closeOnlineWorkspace(tester);
  });
  testWidgets(
    'owner can accept or decline requests; failures keep request pending',
    (tester) async {
      final repository = FakeOnlineRepository()
        ..teamRows = const [
          SalonStaff(
            id: 'ali',
            name: 'Ali',
            isWorking: false,
            joinStatus: 'pending',
          ),
          SalonStaff(
            id: 'bilal',
            name: 'Bilal',
            isWorking: false,
            joinStatus: 'pending',
          ),
        ];
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: ToastService.messengerKey,
          home: StaffScreen(
            repository: repository,
            businessId: 'salon',
            showRequests: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Bilal'), findsOneWidget);
      expect(find.text('Invite employee'), findsNothing);
      repository.rejectJoinReview = true;
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not review request. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Bilal'), findsOneWidget);
      repository.rejectJoinReview = false;
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      // Approval opens contract setup immediately.
      expect(find.text('Save contract'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsNothing);
      expect(find.text('Bilal'), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('No pending join requests.'), findsOneWidget);
      expect(
        repository.teamRows.where((e) => e.joinStatus == 'accepted').single.id,
        'ali',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('employee can see persisted owner decisions and status updates', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()
      ..joinRequestRows = const [
        SalonJoinRequest(
          id: 'one',
          businessName: 'Ali Salon',
          status: 'pending',
        ),
        SalonJoinRequest(
          id: 'two',
          businessName: 'Other Salon',
          status: 'declined',
        ),
      ];
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      MaterialApp(home: JoinSalon(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for owner approval'), findsOneWidget);
    expect(find.text('Request declined'), findsOneWidget);
    repository.joinRequestRows = const [
      SalonJoinRequest(
        id: 'one',
        businessName: 'Ali Salon',
        status: 'accepted',
      ),
    ];
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Joined · view your contracts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
