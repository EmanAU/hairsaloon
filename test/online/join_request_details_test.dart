import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/join_requests_screen.dart';
import 'package:hairsaloon/src/online/presentation/contracts_screen.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'fake_online_repository.dart';
import 'customer_experience_test.dart' show loadFonts, capture;

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('review join request details then set contract at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeOnlineRepository()
        ..teamRows = const [
          SalonStaff(
            id: 'employee',
            name: 'Hassan Ali',
            isWorking: false,
            joinStatus: 'pending',
            phone: '+923465501748',
            cnic: '1234512345671',
          ),
        ];
      addTearDown(repository.events.close);
      await loadFonts(tester);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: JoinRequestsScreen(
              repository: repository,
              businessId: 'salon',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('03465501748'), findsOneWidget);
      expect(find.text('12345-1234567-1'), findsOneWidget);
      await capture(tester, key, 'join-request-details-$width');
      await tester.ensureVisible(find.text('Accept & set contract'));
      await tester.tap(find.text('Accept & set contract'));
      await tester.pumpAndSettle();
      expect(repository.teamRows.single.joinStatus, 'accepted');
      expect(find.byType(ProposeContractPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
