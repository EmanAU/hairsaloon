import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/staff_screen.dart';
import 'package:hairsaloon/src/online/presentation/business_home.dart';
import 'package:hairsaloon/src/online/presentation/contracts_screen.dart';
import 'fake_online_repository.dart';

void main() {
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
          home: StaffScreen(repository: repository, businessId: 'salon'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requests (2)'), findsOneWidget);
      expect(find.text('Invite employee'), findsNothing);
      repository.rejectJoinReview = true;
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not review request. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Requests (2)'), findsOneWidget);
      repository.rejectJoinReview = false;
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(find.text('Requests (1)'), findsOneWidget);
      expect(find.text('Employees (1)'), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Requests (0)'), findsOneWidget);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Bilal'), findsNothing);
      await tester.tap(find.text('Ali'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ContractsScreen>(find.byType(ContractsScreen))
            .employee
            ?.id,
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
