import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';

void main() {
  testWidgets('themed notification can be dismissed with its close button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: ToastService.messengerKey,
      home: const Scaffold(body: SizedBox()),
    ));
    ToastService.success('Bill saved successfully');
    await tester.pumpAndSettle();
    expect(find.text('Bill saved successfully'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pumpAndSettle();
    expect(find.text('Bill saved successfully'), findsNothing);
  });
}
