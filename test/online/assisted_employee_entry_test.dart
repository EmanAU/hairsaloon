import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/online_app.dart';
import 'package:hairsaloon/src/online/presentation/profile_form.dart';
import 'package:hairsaloon/src/online/presentation/employee_home.dart';
import 'fake_online_repository.dart';

class AssistedRepository extends FakeOnlineRepository {
  @override
  Future<void> respondToEmployeeInvite(String id, bool accept) async {
    await super.respondToEmployeeInvite(id, accept);
    if (accept) {
      workspace = OnlineWorkspace(
        account: workspace.account,
        profile: PersonalProfile(
          code: 'profile',
          phone: '+923001234568',
          cnic: '1234512345671',
          dateOfBirth: DateTime(1997),
          workStartedOn: DateTime(2015),
          photoPath: 'employee/photo.png',
        ),
      );
    }
  }
}

void main() {
  testWidgets(
    'invited Google user skips onboarding, accepts, leaves, and can use normal join/setup',
    (tester) async {
      final repository = AssistedRepository()..userId = 'employee';
      repository.workspace = const OnlineWorkspace(
        account: OnlineAccount(id: 'employee', name: 'Hassan'),
      );
      repository.pendingInviteRows = const [
        PendingEmployeeInvite(
          id: 'invite',
          businessId: 'salon',
          businessName: 'Ali Salon',
          ownerName: 'Owner',
          cnic: '1234512345671',
          phone: '+923001234568',
          email: 'staff@example.test',
        ),
      ];
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        OnlineApp(audience: AppAudience.business, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileForm), findsNothing);
      expect(find.text('Start a business'), findsNothing);
      expect(find.text('Join a salon'), findsNothing);
      await tester.tap(find.text('Yes, join Ali Salon'));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.text('Active employee'), findsOneWidget);
      expect(find.text('Start a business'), findsNothing);
      expect(find.text('Join a salon'), findsNothing);
      final leave = find.text('Leave business');
      await tester.ensureVisible(leave);
      await tester.tap(leave);
      // The leave action stays busy while its confirmation dialog is open.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, 'Leave business'));
      await tester.pumpAndSettle();
      expect(repository.leftBusiness, 'salon');
      expect(find.text('Start a business'), findsOneWidget);
      expect(find.text('Join a salon'), findsOneWidget);
      expect(find.text('Leave business'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
