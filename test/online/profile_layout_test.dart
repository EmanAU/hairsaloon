import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/presentation/profile_form.dart';
import 'package:hairsaloon/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:hairsaloon/src/online/presentation/business_home.dart';
import 'package:hairsaloon/src/online/presentation/business_form.dart';
import 'package:hairsaloon/src/online/presentation/staff_screen.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'fake_online_repository.dart';
import 'workspace_test_environment.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('profile fits ${size.width.toInt()} including keyboard', (
      tester,
    ) async {
      await prepareOnlineWorkspace(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = FakeOnlineRepository()
        ..userId = '9a0a8b15-b923-43ef-9f34-6acf4d7e2206';
      addTearDown(repository.events.close);
      if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final configFile = File('.dart_tool/package_config.json').absolute;
          final config =
              jsonDecode(await configFile.readAsString())
                  as Map<String, dynamic>;
          final flutterPackage = (config['packages'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((p) => p['name'] == 'flutter');
          final sdk = Directory.fromUri(
            configFile.uri.resolve(flutterPackage['rootUri'] as String),
          ).parent.parent;
          final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
          for (final family in ['Roboto', 'Ahem']) {
            await (FontLoader(family)..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('$fonts/roboto-regular.ttf').readAsBytes(),
                    ),
                  ),
                ))
                .load();
          }
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '$fonts/materialicons-regular.otf',
                    ).readAsBytes(),
                  ),
                ),
              ))
              .load();
          await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
                rootBundle.load(
                  'packages/cupertino_icons/assets/CupertinoIcons.ttf',
                ),
              ))
              .load();
        });
      }
      final boundaryKey = GlobalKey();
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('EXPORT_SCREENSHOTS')) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'screenshots/profile_onboarding/${name}_${size.width.toInt()}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: ProfileForm(
              repository: repository,
              name: 'Abdullah',
              onboarding: true,
              onSaved: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('profile');
      await tester.showKeyboard(
        find.widgetWithText(TextFormField, 'Full name'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save & continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save & continue').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      final session = OnlineSession(repository);
      addTearDown(session.dispose);
      await session.reload();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: BusinessHome(
              session: session,
              onSignOut: repository.signOut,
              onOpenOffline: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Start a business'), findsOneWidget);
      expect(find.text('Join a salon'), findsOneWidget);
      expect(find.text('Employees & contracts'), findsNothing);
      await capture('workspace');
      await tester.tap(find.text('Start a business'));
      await tester.pumpAndSettle();
      expect(find.text('Add business photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('business');
      await tester.showKeyboard(
        find.widgetWithText(TextFormField, 'Business name'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save business'));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessForm), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join a salon'));
      await tester.pumpAndSettle();
      await capture('join');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final id = await repository.saveBusiness(
        name: 'Abdullah Salon',
        phone: '03127712502',
        type: 'Hair Salon',
        city: 'Lahore',
        area: 'Gulberg',
        address: 'Main Road',
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: OwnerBusiness(repository: repository, businessId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.text('Employees & contracts'), findsNothing);
      await capture('approval');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repository.teamRows = const [
        SalonStaff(
          id: 'employee',
          name: 'Ali Khan',
          isWorking: false,
          joinStatus: 'pending',
        ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: StaffScreen(repository: repository, businessId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('join_requests');
      await tester.pumpWidget(const SizedBox());
      final saved = repository.workspace.businesses.single;
      repository.userId = repository.workspace.account.id;
      repository.workspace = OnlineWorkspace(
        account: repository.workspace.account,
        profile: repository.workspace.profile,
        businesses: [
          SalonBusiness(
            id: saved.id,
            name: saved.name,
            phone: saved.phone,
            type: saved.type,
            city: saved.city,
            area: saved.area,
            address: saved.address,
            isActive: true,
          ),
        ],
      );
      await preopenOnlineWorkspace(tester, repository);
      await session.reload();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: BusinessHome(
              session: session,
              onSignOut: repository.signOut,
              onOpenOffline: () {},
            ),
          ),
        ),
      );
      await waitForOnlineDashboard(tester);
      expect(find.text('Rate List'), findsOneWidget);
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('Join requests'), findsOneWidget);
      await capture('online_dashboard');
      final contracts = find
          .ancestor(
            of: find.text('Contracts'),
            matching: find.byType(DashboardShortcut),
          )
          .first;
      await tester.ensureVisible(contracts);
      await tester.pumpAndSettle();
      await capture('online_dashboard_tools');
      await tester.tap(contracts);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(StaffScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        size.width >= 600
            ? find.text('Billing').last
            : find.byTooltip('Billing'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('New Ticket'),
        size.width >= 600 ? findsOneWidget : findsNothing,
      );
      await capture('online_billing');
      await tester.tap(
        size.width >= 600 ? find.text('Home').last : find.byTooltip('Home'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sync status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync status'));
      await tester.pumpAndSettle();
      expect(find.text('Sync now'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to dashboard'));
      await waitForOnlineDashboard(tester);
      await tester.ensureVisible(find.text('Switch business'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch business'));
      await tester.pumpAndSettle();
      expect(find.text('Your workspace'), findsOneWidget);
      // One owner → one shop: do not offer starting another business.
      expect(find.text('Start a business'), findsNothing);
      expect(find.text('Join a salon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await closeOnlineWorkspace(tester);
    });
  }
}
