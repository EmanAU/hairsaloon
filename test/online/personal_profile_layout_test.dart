import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/profile_form.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'customer_experience_test.dart' show loadFonts;
import 'fake_online_repository.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    testWidgets('compact personal profile fits ${size.width} and keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await loadFonts(tester);
      final repo = FakeOnlineRepository()..userId = 'owner';
      addTearDown(repo.events.close);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light().copyWith(
              appBarTheme: AppTheme.light().appBarTheme.copyWith(
                titleTextStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
            ),
            home: ProfileForm(
              repository: repo,
              name: 'Abdullah',
              onboarding: true,
              onSaved: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/mobile-fix/personal-profile-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.showKeyboard(
        find.widgetWithText(TextFormField, 'Mobile number'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save & continue'));
      await tester.pumpAndSettle();
      expect(find.text('Save & continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.testTextInput.hide();
    });
  }
  testWidgets('compact profile still saves personal identity and continues', (
    tester,
  ) async {
    final repo = FakeOnlineRepository()..userId = 'owner';
    addTearDown(repo.events.close);
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfileForm(
          repository: repo,
          name: 'Ali Khan',
          onboarding: true,
          onSaved: () async {
            continued = true;
          },
          profile: PersonalProfile(
            code: 'personal',
            phone: '03465501748',
            cnic: '1234512345671',
            dateOfBirth: DateTime(1997),
            workStartedOn: DateTime(2016),
            photoPath: 'owner/personal.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save & continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();
    expect(repo.profileSaves, 1);
    expect(continued, isTrue);
    expect(repo.workspace.account.name, 'Ali Khan');
    expect(repo.workspace.profile!.phone, '03465501748');
    expect(tester.takeException(), isNull);
  });
}
