import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hairsaloon/src/features/billing/presentation/billing_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expenses_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/workspace_screen.dart';
import 'package:hairsaloon/src/online/presentation/invite_qr_screen.dart';
import 'package:hairsaloon/src/online/presentation/join_requests_screen.dart';
import 'package:hairsaloon/src/online/presentation/business_owner_details_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/sales_screen.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'fake_online_repository.dart';
import 'workspace_test_environment.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 700),
    const Size(1280, 800),
  ]) {
    testWidgets('business home actions and navigation at ${size.width}', (
      tester,
    ) async {
      await prepareOnlineWorkspace(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const business = SalonBusiness(
        id: '00000000-0000-4000-8000-000000000001',
        name: 'Ali Hair Studio',
        phone: '+923465501748',
        type: 'Salon',
        city: 'Lahore',
        area: 'Gulberg',
        address: 'Main Road, Gulberg',
        isActive: true,
      );
      final repository = FakeOnlineRepository()..userId = 'owner';
      repository.workspace = OnlineWorkspace(
        account: const OnlineAccount(id: 'owner', name: 'Abdullah'),
        profile: PersonalProfile(
          code: 'owner-profile',
          phone: '+923001234567',
          cnic: '1234512345671',
          dateOfBirth: DateTime(1995, 1, 1),
          workStartedOn: DateTime(2015, 1, 1),
        ),
        businesses: const [business],
      );
      addTearDown(repository.events.close);
      await preopenOnlineWorkspace(tester, repository);
      {
        await tester.runAsync(() async {
          const fonts =
              'C:/flutter_windows_3.38.4-stable/flutter/bin/cache/artifacts/material_fonts';
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
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: WorkspaceScreen(repository: repository, business: business),
          ),
        ),
      );
      await waitForOnlineDashboard(tester);
      expect(find.text('New Bill'), findsOneWidget);
      expect(find.text('Rate List'), findsOneWidget);
      expect(find.text('Sales History'), findsOneWidget);
      expect(find.text('Join Requests'), findsOneWidget);
      expect(find.text('Finance'), findsNothing);
      expect(find.text('View Activity'), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/mobile-fix/business-home-${size.width.toInt()}.png',
          );
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('QR codes'));
      await tester.pumpAndSettle();
      expect(find.byType(InviteQrScreen), findsOneWidget);
      expect(find.text('Salon joining code'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business Details'));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessOwnerDetailsScreen), findsOneWidget);
      expect(find.text('Business phone'), findsOneWidget);
      final personalPhone = find.text('Personal phone');
      await tester.scrollUntilVisible(
        personalPhone,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('03001234567'), findsOneWidget);
      expect(find.text('12345-1234567-1'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go Online'));
      await tester.pumpAndSettle();
      expect(find.text('Sync status'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to dashboard'));
      await tester.pumpAndSettle();
      await waitForOnlineDashboard(tester);
      await tester.tap(find.text('Sales History'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesScreen), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Requests'));
      await tester.pumpAndSettle();
      expect(find.byType(JoinRequestsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Billing'));
      await tester.pumpAndSettle();
      expect(find.byType(BillingScreen), findsOneWidget);
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesScreen), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('New Bill'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await closeOnlineWorkspace(tester);
    });
  }
}
