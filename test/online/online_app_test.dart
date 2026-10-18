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
  final completeProfile = PersonalProfile(
    code: 'permanent-code',
    phone: '+923001234567',
    cnic: '1234512345671',
    dateOfBirth: DateTime(1995, 1, 1),
    workStartedOn: DateTime(2015, 1, 1),
    photoPath: 'user/photo.jpg',
  );

  testWidgets('completed profiles proceed to business setup', (tester) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    repository.workspace = OnlineWorkspace(
      account: repository.workspace.account,
      profile: completeProfile,
    );
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start a business'), findsOneWidget);
    expect(find.text('Join a salon'), findsOneWidget);
    expect(find.text('Employees & contracts'), findsNothing);
    await tester.tap(find.text('Join a salon'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('My contracts'), findsOneWidget);
    await tester.tap(find.byTooltip('My contracts'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractsScreen), findsOneWidget);
    expect(find.byType(ProfileForm), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('new businesses open their own employee management', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    repository.workspace = OnlineWorkspace(
      account: repository.workspace.account,
      profile: completeProfile,
    );
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a business'));
    await tester.pumpAndSettle();
    for (final entry in {
      'Business name': 'Ali Salon',
      'Business phone': '03127712502',
      'City': 'Lahore',
      'Area': 'Gulberg',
      'Address': 'Main Road',
    }.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find
        .ancestor(
          of: find.text('Save business'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        )
        .first;
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.businessSaves, 1);
    expect(find.text('Ali Salon'), findsOneWidget);
    expect(find.text('Employees & contracts'), findsOneWidget);
    await tester.ensureVisible(find.text('Employees & contracts'));
    await tester.tap(find.text('Employees & contracts'));
    await tester.pumpAndSettle();
    expect(find.text('Invite employee'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('legacy incomplete profiles return to onboarding on sign-in', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    repository.workspace = OnlineWorkspace(
      account: repository.workspace.account,
      profile: const PersonalProfile(code: 'old-code', phone: '+923001234567'),
    );
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileForm), findsOneWidget);
    expect(find.text('Start a business'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saving profile keeps its code and reloads completed details', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'user';
    repository.workspace = OnlineWorkspace(
      account: repository.workspace.account,
      profile: PersonalProfile(
        code: completeProfile.code,
        phone: completeProfile.phone,
        cnic: completeProfile.cnic,
        dateOfBirth: completeProfile.dateOfBirth,
        photoPath: completeProfile.photoPath,
      ),
    );
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      OnlineApp(audience: AppAudience.business, repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Ali Khan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '03127712502',
    );
    final startDate = find
        .ancestor(
          of: find.text('Working since'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.ensureVisible(startDate);
    await tester.tap(startDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save & continue'));
    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();
    expect(repository.profileSaves, 1);
    expect(find.text('Start a business'), findsOneWidget);
    expect(find.byType(ProfileForm), findsNothing);
    expect(repository.workspace.account.name, 'Ali Khan');
    expect(repository.workspace.profile!.phone, '03127712502');
    expect(repository.workspace.profile!.code, 'permanent-code');
    await tester.pumpWidget(const SizedBox());
  });

  test('experience is derived from start date using full calendar months', () {
    expect(
      completeProfile.experienceAt(DateTime(2026, 10, 18)),
      '11 years 9 months',
    );
    expect(
      completeProfile.experienceAt(DateTime(2015, 1, 20)),
      'Less than a month',
    );
    expect(completeProfile.isComplete, isTrue);
    expect(
      const PersonalProfile(code: 'code', phone: 'phone').isComplete,
      isFalse,
    );
  });
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

  testWidgets(
    'new business users must complete their profile before business',
    (tester) async {
      final repository = FakeOnlineRepository()..userId = 'user';
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        OnlineApp(audience: AppAudience.business, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileForm), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Start a business'), findsNothing);
      expect(find.text('Join a salon by code'), findsNothing);
      expect(find.byType(ProfileForm), findsOneWidget);
      expect(find.text('CNIC'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
    await tester.ensureVisible(find.text('Save profile'));
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
