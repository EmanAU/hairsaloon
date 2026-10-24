import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hairsaloon/src/online/presentation/invite_qr_screen.dart';
import 'package:hairsaloon/src/online/domain/qr_destination.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'fake_online_repository.dart';
import 'customer_experience_test.dart' show loadFonts, capture;

class _Repository extends FakeOnlineRepository {
  int inviteCalls = 0;
  @override
  Future<String> businessInvite(String businessId) async {
    inviteCalls++;
    return '00000000-0000-4000-8000-000000000001';
  }
}

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('separate customer and staff QR flows at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repository = _Repository();
      addTearDown(repository.events.close);
      await loadFonts(tester);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: InviteQrScreen(
              repository: repository,
              businessId: '00000000-0000-4000-8000-000000000002',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, 'qr-choices-${width.toInt()}');
      expect(find.byType(QrImageView), findsNothing);
      expect(repository.inviteCalls, 0);
      await tester.tap(find.text('Customer salon QR'));
      await tester.pumpAndSettle();
      expect(repository.inviteCalls, 0);
      expect(find.text('Salon joining code'), findsNothing);
      await capture(tester, key, 'qr-customer-${width.toInt()}');
      await tester.ensureVisible(find.text('Copy salon link'));
      await tester.tap(find.text('Copy salon link'));
      await tester.pumpAndSettle();
      expect(
        copied,
        const QrDestination(
          'salon',
          '00000000-0000-4000-8000-000000000002',
        ).value,
      );
      await tester.ensureVisible(find.text('Change QR type'));
      await tester.tap(find.text('Change QR type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee invitation'));
      await tester.pumpAndSettle();
      expect(repository.inviteCalls, 1);
      await capture(tester, key, 'qr-employee-${width.toInt()}');
      await tester.ensureVisible(find.text('Copy invitation link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy invitation link'));
      await tester.pumpAndSettle();
      expect(
        copied,
        const QrDestination(
          'join',
          '00000000-0000-4000-8000-000000000001',
        ).value,
      );
      expect(find.text('00000000-0000-4000-8000-000000000001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a QR code'), findsOneWidget);
    });
  }
}
