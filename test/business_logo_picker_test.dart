import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/business_logo_picker.dart';

class _Picker extends ImagePicker {
  _Picker(this.file);
  final XFile? file;
  ImageSource? selectedSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    selectedSource = source;
    return file;
  }
}

void main() {
  testWidgets('gallery selection previews logo and remove clears selection', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(
      () => File('assets/logo.png').readAsBytes(),
    ))!;
    final picker = _Picker(XFile.fromData(bytes, name: 'shop.png'));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => BusinessLogoPicker(
              value: selected,
              picker: picker,
              onChanged: (value) => update(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(picker.selectedSource, ImageSource.gallery);
    expect(selected, isNotNull);
    final normalized = base64Decode(selected!);
    expect(normalized.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(normalized.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('cancelling gallery preserves existing logo', (tester) async {
    final bytes = (await tester.runAsync(
      () => File('assets/logo.png').readAsBytes(),
    ))!;
    final previous = base64Encode(bytes);
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessLogoPicker(
            value: previous,
            picker: _Picker(null),
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(changed, isFalse);
    expect(find.byType(Image), findsOneWidget);
  });
}
