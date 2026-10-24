import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/online/data/customer_history.dart';
import 'package:hairsaloon/src/online/domain/online_models.dart';
import 'package:hairsaloon/src/online/domain/qr_destination.dart';
import 'package:hairsaloon/src/online/presentation/customer_screens.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'fake_online_repository.dart';

const salon = SalonBusiness(
  id: 'salon',
  name: 'Ali Hair Studio',
  phone: '03465501748',
  type: 'Barber shop',
  city: 'Lahore',
  area: 'Gulberg',
  address: 'Main Boulevard, Gulberg',
  isActive: true,
);

class CustomerRepository extends FakeOnlineRepository {
  bool unavailable = false, failReview = false;
  String? lastBarber;
  final List<Map<String, dynamic>> reviewRows = [];
  CustomerRepository() {
    userId = 'customer';
    serviceRows = const [
      SalonService(
        id: 'cut',
        name: 'Classic Haircut',
        description:
            'A tailored cut, wash and finish. Discuss your preferred style with your barber.',
        price: 800,
        category: 'Hair',
      ),
      SalonService(
        id: 'beard',
        name: 'Beard Trim',
        description: 'Shape, line-up and finish for a neat, natural look.',
        price: 400,
        category: 'Beard',
      ),
      SalonService(
        id: 'hidden',
        name: 'Hidden service',
        description: '',
        price: 1,
        category: 'Other',
        isActive: false,
      ),
    ];
  }
  @override
  Future<SalonBusiness?> findBusiness(String id, {bool barber = false}) async {
    if (barber) lastBarber = id;
    return unavailable ? null : salon;
  }

  @override
  Future<List<SalonBusiness>> discoverBusinesses({
    String search = '',
    int page = 0,
  }) async => [salon];
  @override
  Future<List<SalonStaff>> staff(String id) async => const [
    SalonStaff(id: 'barber', name: 'Hassan Ali', isWorking: true),
  ];
  @override
  Future<List<Map<String, dynamic>>> reviews(
    String id, {
    String? employeeId,
  }) async => reviewRows.where((r) => r['employee_id'] == employeeId).toList();
  @override
  Future<void> saveReview(
    String businessId,
    int rating,
    String body, {
    String? employeeId,
    String? id,
  }) async {
    if (failReview) throw const OnlineFailure('Connection lost. Please retry.');
    await super.saveReview(
      businessId,
      rating,
      body,
      employeeId: employeeId,
      id: id,
    );
    reviewRows.removeWhere((r) => r['employee_id'] == employeeId);
    reviewRows.add({
      'id': id ?? 'review',
      'author_id': userId,
      'employee_id': employeeId,
      'rating': rating,
      'body': body,
      'created_at': '2026-10-25T10:00:00Z',
    });
  }
}

Future<void> loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final package = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      configFile.uri.resolve(package['rootUri'] as String),
    ).parent.parent;
    final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
    for (final name in ['Roboto', 'Ahem']) {
      await (FontLoader(name)..addFont(
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
              await File('$fonts/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EXPORT_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/mobile-fix').create(recursive: true);
    await File(
      'build/mobile-fix/customer-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'scan history survives reopening, deduplicates repeat scans and isolates accounts',
    () async {
      final store = CustomerHistory('one');
      await store.record(salon);
      await store.record(salon);
      final rows = await CustomerHistory('one').load();
      expect(rows.length, 1);
      expect(rows.single.scans, 2);
      expect(rows.single.business.name, salon.name);
      expect(await CustomerHistory('two').load(), isEmpty);
      await store.clear();
      expect(await store.load(), isEmpty);
    },
  );
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets(
      'customer scan, service detail, review and repeat history at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadFonts(tester);
        final repo = CustomerRepository();
        addTearDown(repo.events.close);
        var scans = 0;
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
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              home: CustomerDirectory(
                repository: repo,
                onSignOut: repo.signOut,
                scanDestination: (_) async => QrDestination(
                  ++scans == 1 ? 'salon' : 'barber',
                  scans == 1 ? 'salon' : 'barber',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, boundary, 'home-${width.toInt()}');
        await tester.tap(find.text('Scan salon QR'));
        await tester.pumpAndSettle();
        expect(find.byType(SalonDetails), findsOneWidget);
        expect(find.text('Hidden service'), findsNothing);
        await capture(tester, boundary, 'salon-${width.toInt()}');
        // The top review button works even before the lazy review panel is built.
        await tester.tap(find.text('Write a review'));
        await tester.pumpAndSettle();
        await capture(tester, boundary, 'review-${width.toInt()}');
        await tester.tap(find.byTooltip('4 stars'));
        await tester.enterText(
          find.byType(TextFormField),
          'Great service and a clean finish.',
        );
        final save = find.text('Save review');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.reviewSaves, 1);
        expect(repo.reviewRows.single['rating'], 4);
        await tester.ensureVisible(find.text('Beard').first);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Beard'));
        await tester.pumpAndSettle();
        expect(find.text('Classic Haircut'), findsNothing);
        await tester.ensureVisible(find.text('Beard Trim'));
        await tester.tap(find.text('Beard Trim'));
        await tester.pumpAndSettle();
        expect(find.byType(ServiceDetailPage), findsOneWidget);
        expect(find.text('Rs 400'), findsOneWidget);
        expect(
          find.text('Shape, line-up and finish for a neat, natural look.'),
          findsOneWidget,
        );
        await capture(tester, boundary, 'service-${width.toInt()}');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Salon menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Write or edit review'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(
            TextFormField,
            'Great service and a clean finish.',
          ),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.textContaining('Scanned once'), findsOneWidget);
        await tester.ensureVisible(find.text('Scan salon QR'));
        await tester.tap(find.text('Scan salon QR'));
        await tester.pumpAndSettle();
        expect(repo.lastBarber, 'barber');
        expect(find.text('Reviewing Hassan Ali'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Scanned salons'));
        await tester.tap(find.text('Scanned salons'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Scanned 2 times'), findsOneWidget);
        expect(find.text('Ali Hair Studio'), findsOneWidget);
        await capture(tester, boundary, 'history-${width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'review failure retains draft and selected stars, then retry succeeds',
    (tester) async {
      final repo = CustomerRepository()..failReview = true;
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().copyWith(
            appBarTheme: AppTheme.light().appBarTheme.copyWith(
              titleTextStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          home: SalonDetails(
            repository: repo,
            business: salon,
            barberId: 'barber',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write a review'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('3 stars'));
      await tester.enterText(find.byType(TextFormField), 'Keep this draft');
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(find.text('Connection lost. Please retry.'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Keep this draft'),
        findsOneWidget,
      );
      repo.failReview = false;
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(repo.reviewRows.single['rating'], 3);
      expect(repo.savedReviewEmployee, 'barber');
      expect(find.byType(SalonDetails), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancelled or unavailable QR does not add scan history', (
    tester,
  ) async {
    final repo = CustomerRepository()..unavailable = true;
    addTearDown(repo.events.close);
    QrDestination? target;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDirectory(
          repository: repo,
          onSignOut: repo.signOut,
          scanDestination: (_) async => target,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan salon QR'));
    await tester.pumpAndSettle();
    expect(await CustomerHistory('customer').load(), isEmpty);
    target = const QrDestination('salon', 'salon');
    await tester.tap(find.text('Scan salon QR'));
    await tester.pumpAndSettle();
    expect(find.byType(SalonDetails), findsNothing);
    expect(await CustomerHistory('customer').load(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
