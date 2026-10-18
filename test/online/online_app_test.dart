import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/online_app.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'package:hairsaloon/src/online/presentation/profile_form.dart';
import 'package:hairsaloon/src/online/presentation/contracts_screen.dart';
import 'fake_online_repository.dart';

void main() {
  testWidgets('contract conflict stays visible without claiming acceptance', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()
      ..rejectAcceptance = true
      ..contractRows = [
        WorkContract(
          id: 'contract',
          employeeId: 'employee',
          kind: 'permanent',
          startsAt: DateTime.now(),
          endsAt: null,
          status: 'draft',
          salary: 1000,
          commission: 10,
          terms: 'Monthly',
          businessName: 'Test Salon',
        ),
      ];
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      MaterialApp(home: ContractsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept contract'));
    await tester.pumpAndSettle();
    expect(find.text('Contract overlaps another salon.'), findsOneWidget);
    expect(find.text('PERMANENT · draft'), findsOneWidget);
  });
  testWidgets('unconfigured business app preserves an offline entry', (
    tester,
  ) async {
    await tester.pumpWidget(const OnlineApp(audience: AppAudience.business));
    expect(find.text('Online setup is not connected yet.'), findsOneWidget);
    expect(find.text('Open offline business app'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('customer entry never opens the business offline workspace', (
    tester,
  ) async {
    await tester.pumpWidget(const OnlineApp(audience: AppAudience.customer));
    expect(find.text('Open offline business app'), findsNothing);
    expect(find.text('Find your next haircut.'), findsOneWidget);
  });

  testWidgets('Google button delegates sign-in to the repository', (
    tester,
  ) async {
    final repository = FakeOnlineRepository();
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(repository.signInCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('new business users choose a personal profile or a business', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create personal profile'), findsOneWidget);
    expect(find.text('Start a business'), findsOneWidget);
    expect(find.text('Join a salon by code'), findsNothing);
    await tester.tap(find.text('Start a business'));
    await tester.pumpAndSettle();
    expect(find.text('Personal profile'), findsOneWidget);
    expect(find.text('CNIC'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('customer logout clears protected detail navigation', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.customer, repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Salon'));
    await tester.pumpAndSettle();
    expect(find.text('Haircut'), findsOneWidget);
    await repository.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Haircut'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid profile fields cannot be submitted', (tester) async {
    final repository = FakeOnlineRepository();
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      MaterialApp(home: ProfileForm(repository: repository)),
    );
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repository.profileSaves, 0);
    expect(find.text('Enter your 13-digit CNIC'), findsOneWidget);
  });

  test(
    'a slow previous-user response cannot repopulate a signed-out session',
    () async {
      final pending = Completer<OnlineWorkspace>();
      final repository = FakeOnlineRepository()
        ..userId = 'user'
        ..pendingWorkspace = pending.future;
      final session = OnlineSession(repository);
      await repository.signOut();
      await Future<void>.delayed(Duration.zero);
      pending.complete(repository.workspace);
      await Future<void>.delayed(Duration.zero);
      expect(session.workspace, isNull);
      expect(session.signedIn, false);
      expect(session.loading, false);
      session.dispose();
      await repository.events.close();
    },
  );
}
