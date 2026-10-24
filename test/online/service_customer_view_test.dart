import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/presentation/customer_screens.dart';
import 'package:hairsaloon/src/online/presentation/service_customer_view_editor.dart';
import 'package:hairsaloon/src/online/presentation/widgets/service_rich_content.dart';
import 'fake_online_repository.dart';

void main() {
  const salon = SalonBusiness(
    id: 'salon',
    name: 'Test Salon',
    phone: '03000000000',
    type: 'Salon',
    city: 'Lahore',
    area: 'Test',
    address: 'Test address',
    isActive: true,
  );

  test('SalonService parses content_json and detects rich content', () {
    final empty = SalonService.fromJson({
      'id': '1',
      'name': 'Cut',
      'description': 'Plain',
      'price': 100,
      'category': 'Hair',
      'is_active': true,
      'content_json': [
        {'insert': '\n'},
      ],
    });
    expect(empty.hasRichContent, isFalse);

    final rich = SalonService.fromJson({
      'id': '2',
      'name': 'Cut',
      'description': 'Plain',
      'price': 100,
      'category': 'Hair',
      'is_active': true,
      'content_json': [
        {'insert': 'Includes wash and style\n'},
      ],
    });
    expect(rich.hasRichContent, isTrue);
    expect(rich.contentJson, isNotEmpty);
  });

  testWidgets('detail falls back to plain description when JSON empty', (
    tester,
  ) async {
    final repository = FakeOnlineRepository()..userId = 'customer';
    addTearDown(repository.events.close);
    const service = SalonService(
      id: 'service',
      name: 'Haircut',
      description: 'Classic cut with wash',
      price: 500,
      category: 'Hair',
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: ServiceDetailPage(
          repository: repository,
          business: salon,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Classic cut with wash'), findsOneWidget);
    expect(find.text('Rs 500'), findsOneWidget);
  });

  testWidgets('customer view editor saves Quill delta JSON', (tester) async {
    final repository = FakeOnlineRepository()..userId = 'owner';
    addTearDown(repository.events.close);
    final service = repository.serviceRows.first;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: ToastService.messengerKey,
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: ServiceCustomerViewEditor(
          repository: repository,
          businessId: 'salon',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer view'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.lastSavedService, isNotNull);
    expect(repository.lastSavedService!['contentJson'], isA<List>());
    expect(repository.lastSavedService!['id'], service.id);
  });

  testWidgets('ServiceRichContent shows fallback text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ServiceRichContent(
            contentJson: [],
            fallbackDescription: 'Fallback body',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fallback body'), findsOneWidget);
  });
}
