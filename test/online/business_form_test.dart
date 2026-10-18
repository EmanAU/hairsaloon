import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:hairsaloon/src/features/business_profile/domain/business_options.dart';
import 'package:hairsaloon/src/online/presentation/business_form.dart';
import 'fake_online_repository.dart';

class PhotoPicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    File('assets/logo.png').readAsBytesSync(),
    path: 'salon.png',
  );
}

void main() {
  testWidgets(
    'existing business types are selectable and photo retry keeps one business',
    (tester) async {
      final original = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = PhotoPicker();
      addTearDown(() => ImagePickerPlatform.instance = original);
      final repository = FakeOnlineRepository()..failBusinessPhoto = true;
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessForm(repository: repository),
                  ),
                ),
                child: const Text('Register'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      final dropdown = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Business type',
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      for (final type in BusinessOptions.businessTypes) {
        expect(find.text(type), findsWidgets);
      }
      await tester.tap(find.text('Beauty Parlour').last);
      await tester.pumpAndSettle();
      for (final entry in {
        'Business name': 'Ali Salon',
        'Business phone': '03127712502',
        'Area': 'Gulberg',
        'Address': 'Main Road',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final city = find.widgetWithText(DropdownButtonFormField<String>, 'City');
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      for (final name in ['Rawalpindi', 'Islamabad', 'Lahore']) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.tap(find.text('Lahore'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add business photo'));
      await tester.tap(find.text('Add business photo'));
      await tester.pumpAndSettle();
      expect(find.text('Change business photo'), findsOneWidget);
      final save = find
          .ancestor(
            of: find.text('Save business'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.businessSaves, 1);
      expect(repository.businessPhotoUploads, 1);
      expect(
        find.text('Could not upload photo. Please retry.'),
        findsOneWidget,
      );
      expect(repository.workspace.businesses.single.type, 'Beauty Parlour');
      expect(repository.workspace.businesses.single.city, 'Lahore');
      repository.failBusinessPhoto = false;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.businessPhotoUploads, 2);
      expect(repository.workspace.businesses, hasLength(1));
      expect(find.byType(BusinessForm), findsNothing);
    },
  );
}
