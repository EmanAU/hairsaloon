import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/online/presentation/reviews_panel.dart';
import 'fake_online_repository.dart';

void main() {
  testWidgets('review requires text and submits the selected barber target', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'customer';
    addTearDown(repository.events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewsPanel(
              repository: repository,
              businessId: 'salon',
              employeeId: 'barber',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(repository.reviewSaves, 0);
    expect(find.text('Please describe your experience'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Good haircut');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(repository.reviewSaves, 1);
    expect(repository.savedReviewEmployee, 'barber');
    expect(repository.savedReviewBody, 'Good haircut');
  });
}
