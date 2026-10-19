import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/business_home.dart';
import 'package:hairsaloon/src/online/presentation/customer_screens.dart';
import 'package:hairsaloon/src/online/presentation/employee_home.dart';
import 'package:hairsaloon/src/online/presentation/online_session.dart';
import 'package:hairsaloon/src/online/presentation/rate_list_screen.dart';
import 'package:hairsaloon/src/online/presentation/staff_screen.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';

import 'fake_online_repository.dart';

const _export = bool.fromEnvironment('EXPORT_SCREENSHOTS');

const _salon = SalonBusiness(
  id: 'salon',
  name: 'Cut & Co',
  phone: '03001234567',
  type: 'Salon',
  city: 'Lahore',
  area: 'Gulberg',
  address: '12 Main Boulevard',
  isActive: true,
);

const _pendingSalon = SalonBusiness(
  id: 'salon-pending',
  name: 'Cut & Co',
  phone: '03001234567',
  type: 'Salon',
  city: 'Lahore',
  area: 'Gulberg',
  address: '12 Main Boulevard',
  isActive: false,
);

final _profile = PersonalProfile(
  code: 'permanent-code',
  phone: '+923001234567',
  cnic: '1234512345671',
  dateOfBirth: DateTime(1995, 1, 1),
  workStartedOn: DateTime(2015, 1, 1),
  photoPath: 'user/photo.jpg',
);

void main() {
  for (final entry in <String, Size>{
    'mobile': const Size(390, 844),
    'tablet': const Size(800, 1280),
  }.entries) {
    group('online screenshot audit · ${entry.key}', () {
      late GlobalKey boundaryKey;

      Future<void> settleBriefly(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }

      Future<void> capture(WidgetTester tester, String pack, String name) async {
        expect(tester.takeException(), isNull, reason: '$pack/$name');
        if (!_export) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await settleBriefly(tester);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('screenshots/${pack}_${entry.key}');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> pumpFrame(WidgetTester tester, Widget home) async {
        boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              theme: AppTheme.light(),
              scaffoldMessengerKey: ToastService.messengerKey,
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: home,
            ),
          ),
        );
        await settleBriefly(tester);
      }

      Future<void> disposeFrame(WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      testWidgets('customer pack', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = FakeOnlineRepository()..userId = 'customer';
        addTearDown(repository.events.close);

        await pumpFrame(
          tester,
          CustomerDirectory(
            repository: repository,
            onSignOut: repository.signOut,
          ),
        );
        expect(find.text('Find a salon'), findsOneWidget);
        await capture(tester, 'customer', '01_directory');

        await pumpFrame(
          tester,
          SalonDetails(repository: repository, business: _salon),
        );
        expect(find.text('Rate list'), findsOneWidget);
        await capture(tester, 'customer', '02_salon_details');

        await pumpFrame(
          tester,
          ServiceDetailPage(
            repository: repository,
            business: _salon,
            service: repository.serviceRows.first,
          ),
        );
        expect(find.text('Haircut'), findsWidgets);
        await capture(tester, 'customer', '03_service_detail');
        await disposeFrame(tester);
      });

      testWidgets('business employee pack', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final repository = FakeOnlineRepository()..userId = 'barber';
        repository.workspace = OnlineWorkspace(
          account: const OnlineAccount(id: 'barber', name: 'Ali Barber'),
          profile: _profile,
          businesses: const [_salon],
        );
        repository.employeeDashboardData = EmployeeDashboardData(
          contracts: [
            WorkContract(
              id: 'c1',
              employeeId: 'e1',
              businessId: 'salon',
              kind: 'daily',
              startsAt: today.subtract(const Duration(days: 1)),
              endsAt: null,
              status: 'accepted',
              salary: 0,
              commission: 40,
              terms: '',
              businessName: 'Cut & Co',
            ),
          ],
          joinRequests: const [],
          days: [
            EmployeeDayWork(
              date: today,
              jobs: [
                EmployeeWorkJob(
                  id: 'b1',
                  createdAt: today.add(const Duration(hours: 14)),
                  customerName: 'Hassan',
                  total: 1000,
                  services: const ['Haircut'],
                  businessName: 'Cut & Co',
                  commissionPercent: 40,
                ),
              ],
            ),
          ],
        );
        repository.pendingInviteRows = [
          const PendingEmployeeInvite(
            id: 'inv1',
            businessId: 'salon',
            businessName: 'Cut & Co',
            ownerName: 'Owner',
            cnic: '1234512345671',
            phone: '+923001234567',
            email: 'owner@example.com',
          ),
        ];
        repository.managerBusinessRows = [
          const ManagerBusiness(
            businessId: 'salon',
            businessName: 'Cut & Co',
            membershipId: 'm1',
          ),
        ];
        addTearDown(repository.events.close);

        final session = OnlineSession(repository);
        addTearDown(session.dispose);
        await session.reload();

        await pumpFrame(
          tester,
          EmployeeHome(session: session, onSignOut: repository.signOut),
        );
        expect(find.text('My work'), findsOneWidget);
        await capture(tester, 'business_employee', '01_employee_home');

        await pumpFrame(
          tester,
          OwnerBusiness(
            repository: repository,
            businessId: 'salon',
            managementOnly: true,
          ),
        );
        expect(find.text('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('Managers cannot open billing'),
          findsOneWidget,
        );
        await capture(tester, 'business_employee', '02_manager_tools');
        await disposeFrame(tester);
      });

      testWidgets('business owner pack', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = FakeOnlineRepository()..userId = 'owner';
        // Pending salon keeps BusinessHome on approval chrome (active opens POS).
        repository.workspace = OnlineWorkspace(
          account: const OnlineAccount(id: 'owner', name: 'Sara Owner'),
          profile: _profile,
          businesses: const [_pendingSalon],
        );
        addTearDown(repository.events.close);

        final session = OnlineSession(repository);
        addTearDown(session.dispose);
        await session.reload();

        await pumpFrame(
          tester,
          BusinessHome(
            session: session,
            onSignOut: repository.signOut,
            onOpenOffline: () {},
          ),
        );
        expect(find.text('Your workspace'), findsOneWidget);
        await capture(tester, 'business_owner', '01_business_home');
        await disposeFrame(tester);

        repository.workspace = OnlineWorkspace(
          account: const OnlineAccount(id: 'owner', name: 'Sara Owner'),
          profile: _profile,
          businesses: const [_salon],
        );
        await session.reload();

        await pumpFrame(
          tester,
          StaffScreen(repository: repository, businessId: _salon.id),
        );
        await capture(tester, 'business_owner', '02_staff');
        await disposeFrame(tester);

        await pumpFrame(
          tester,
          OnlineRateList(repository: repository, businessId: _salon.id),
        );
        expect(find.text('Haircut'), findsOneWidget);
        await capture(tester, 'business_owner', '03_rate_list');
        await disposeFrame(tester);

        await pumpFrame(
          tester,
          OwnerBusiness(
            repository: repository,
            businessId: _salon.id,
            managementOnly: true,
          ),
        );
        expect(find.text('Employees & contracts'), findsOneWidget);
        await capture(tester, 'business_owner', '04_owner_management');
        await disposeFrame(tester);
      });
    });
  }
}
