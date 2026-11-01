import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/features/printing/domain/receipt_printer.dart';
import 'package:hairsaloon/src/features/printing/data/local_printer_preferences.dart';
import 'package:hairsaloon/src/features/printing/data/android_receipt_printer.dart';
import 'package:hairsaloon/src/features/printing/data/receipt_encoder.dart';
import 'package:hairsaloon/src/features/printing/presentation/receipt_printer_store.dart';
import 'package:hairsaloon/src/features/printing/presentation/printer_settings_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/receipt_dialog.dart';
import 'package:hairsaloon/src/features/billing/presentation/receipt_share_mixin.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';

const system = ReceiptPrinterConfig(connection: ReceiptConnection.system);
const network = ReceiptPrinterConfig(
  connection: ReceiptConnection.network,
  name: 'Counter printer',
  address: '192.168.1.50',
);
PrintableReceipt receipt({int items = 1}) => PrintableReceipt(
  bill: Bill(
    id: 'bill-123456',
    createdAt: DateTime(2026, 11, 2, 14, 30),
    customerName: 'Customer',
    customerPhone: '03001234567',
    employeeName: 'Barber',
    paymentType: 'Cash',
    lines: List.generate(
      items,
      (i) => const BillLine(
        serviceName: 'Haircut and styling',
        qty: 2,
        price: 100.25,
      ),
    ),
    subTotal: 200.50,
    discountType: BillDiscountType.amount,
    discountValue: 20,
    discountAmount: 20,
    taxPercent: 17,
    taxAmount: 30.685,
    grandTotal: 211.185,
  ),
  businessName: 'Salon',
  businessPhone: '03001234567',
  businessAddress: 'Lahore',
  currency: 'PKR',
);

Future<void> exportThermalPreview(List<int> bytes) async {
  final strips = <img.Image>[];
  for (var offset = 0; offset < bytes.length - 8; offset++) {
    if (bytes[offset] != 29 ||
        bytes[offset + 1] != 118 ||
        bytes[offset + 2] != 48) {
      continue;
    }
    final stride = bytes[offset + 4] + 256 * bytes[offset + 5];
    final height = bytes[offset + 6] + 256 * bytes[offset + 7];
    final image = img.Image(width: stride * 8, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < stride * 8; x++) {
        final byte = bytes[offset + 8 + y * stride + x ~/ 8];
        final value = byte & (128 >> (x % 8)) == 0 ? 255 : 0;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    strips.add(image);
    offset += 7 + stride * height;
  }
  final output = img.Image(
    width: strips.first.width,
    height: strips.fold<int>(0, (height, image) => height + image.height),
  );
  var y = 0;
  for (final strip in strips) {
    img.compositeImage(output, strip, dstY: y);
    y += strip.height;
  }
  final file = File('build/printer-review/thermal-receipt.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(img.encodePng(output));
}

Future<void> loadReviewFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final flutter = (packages['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((package) => package['name'] == 'flutter');
  final sdk = Directory.fromUri(
    config.uri.resolve(flutter['rootUri'] as String),
  ).parent.parent;
  final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
  for (final family in ['sans-serif', 'Roboto']) {
    await (FontLoader(family)..addFont(
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
}

class FakeHardware implements ReceiptPrinterHardware {
  int prints = 0;
  PrintableReceipt? lastReceipt;
  ReceiptPrinterConfig? lastConfig;
  PrinterFailure? failure;
  Completer<ReceiptPrintResult>? pending;
  ReceiptPrintResult result = ReceiptPrintResult.sent;
  final scan = StreamController<ReceiptPrinterDevice>.broadcast();
  @override
  Stream<ReceiptPrinterDevice> discover(ReceiptConnection connection) =>
      scan.stream;
  @override
  Future<void> openPermissions() async {}
  @override
  Future<ReceiptPrintResult> printReceipt(
    ReceiptPrinterConfig config,
    PrintableReceipt receipt,
  ) async {
    prints++;
    lastReceipt = receipt;
    lastConfig = config;
    if (failure != null) throw failure!;
    return pending?.future ?? Future.value(result);
  }
}

class FixedEncoder implements ReceiptEncoder {
  final List<int> payload = List.generate(32000, (i) => i % 256);
  @override
  Future<List<int>> thermal(
    PrintableReceipt receipt,
    ReceiptPrinterConfig config,
  ) async => payload;
  @override
  Future<Uint8List> pdf(PrintableReceipt receipt) async => Uint8List(0);
}

class FakeProfile extends ChangeNotifier implements BusinessProfileNotifier {
  @override
  BusinessProfile get profile => const BusinessProfile(
    businessName: 'Test Salon',
    phoneNumber: '03001234567',
    businessType: 'Salon',
    city: 'Lahore',
    area: 'Gulberg',
    address: 'Main road',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettings extends ChangeNotifier implements SettingsStore {
  @override
  String get currencyCode => 'PKR';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'system adapter submits the PDF, handles cancellation and blocks another workspace',
    () async {
      final pending = Completer<bool>();
      final encoder = FixedEncoder();
      final firstPrinter = AndroidReceiptPrinter(
        encoder,
        isAndroid: () => true,
        systemPrint: (document, name) {
          expect(name, 'Receipt 123456');
          return pending.future;
        },
      );
      final first = firstPrinter.printReceipt(system, receipt());
      final secondPrinter = AndroidReceiptPrinter(
        encoder,
        isAndroid: () => true,
        systemPrint: (_, _) async => true,
      );
      await expectLater(
        secondPrinter.printReceipt(system, receipt()),
        throwsA(
          isA<PrinterFailure>().having(
            (error) => error.message,
            'message',
            contains('Another receipt'),
          ),
        ),
      );
      pending.complete(false);
      expect(await first, ReceiptPrintResult.cancelled);
      expect(
        await secondPrinter.printReceipt(system, receipt()),
        ReceiptPrintResult.systemSubmitted,
      );
    },
  );

  test(
    'network adapter flushes the entire job to the selected host and port',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = <int>[];
      final finished = Completer<void>();
      final listener = server.listen((socket) {
        socket.listen(
          received.addAll,
          onDone: () {
            socket.destroy();
            finished.complete();
          },
        );
      });
      final encoder = FixedEncoder();
      final hardware = AndroidReceiptPrinter(encoder, isAndroid: () => true);
      try {
        final result = await hardware.printReceipt(
          ReceiptPrinterConfig(
            connection: ReceiptConnection.network,
            address: '127.0.0.1',
            port: server.port,
          ),
          receipt(),
        );
        await finished.future.timeout(const Duration(seconds: 5));
        expect(result, ReceiptPrintResult.sent);
        // The transport initializes the device, then sends the complete receipt.
        expect(received, [27, 64, ...encoder.payload]);
      } finally {
        await listener.cancel();
        await server.close();
      }
    },
  );

  test(
    'unreachable network printer fails without retry and releases the print lock',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = server.port;
      await server.close();
      final hardware = AndroidReceiptPrinter(
        FixedEncoder(),
        isAndroid: () => true,
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          hardware.printReceipt(
            ReceiptPrinterConfig(
              connection: ReceiptConnection.network,
              address: '127.0.0.1',
              port: closedPort,
            ),
            receipt(),
          ),
          throwsA(
            isA<PrinterFailure>().having(
              (error) => error.message,
              'message',
              contains('Could not connect'),
            ),
          ),
        );
      }
    },
  );

  test(
    'printer defaults survive restart and remain isolated by account and salon',
    () async {
      final preferences = LocalPrinterPreferences();
      await preferences.save('owner/shop-a', network);
      await preferences.save('manager/shop-a', system);
      expect(
        (await LocalPrinterPreferences().load('owner/shop-a'))!.address,
        network.address,
      );
      expect(
        (await preferences.load('manager/shop-a'))!.connection,
        ReceiptConnection.system,
      );
      expect(await preferences.load('owner/shop-b'), isNull);
      await preferences.clear('manager/shop-a');
      expect(await preferences.load('manager/shop-a'), isNull);
      expect(await preferences.load('owner/shop-a'), isNotNull);
    },
  );

  test(
    'malformed saved configuration never silently selects a different printer',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final key =
          'receipt_printer.v1.${base64Url.encode(utf8.encode('owner/shop'))}';
      await prefs.setString(key, '{bad json');
      await expectLater(
        LocalPrinterPreferences().load('owner/shop'),
        throwsA(isA<PrinterFailure>()),
      );
    },
  );

  test(
    'invalid addresses, ports and missing devices cannot be saved',
    () async {
      final hardware = FakeHardware();
      addTearDown(hardware.scan.close);
      final actions = ReceiptPrinterActions(
        LocalPrinterPreferences(),
        hardware,
      );
      for (final config in [
        const ReceiptPrinterConfig(
          connection: ReceiptConnection.network,
          address: 'http://printer:9100',
        ),
        const ReceiptPrinterConfig(
          connection: ReceiptConnection.network,
          address: 'printer.local',
          port: 70000,
        ),
        const ReceiptPrinterConfig(connection: ReceiptConnection.bluetooth),
        const ReceiptPrinterConfig(connection: ReceiptConnection.usb),
        const ReceiptPrinterConfig(
          connection: ReceiptConnection.network,
          address: 'printer.local',
          paperMm: 58,
          dots: 576,
        ),
      ]) {
        expect(
          () => actions.save('owner/shop', config),
          throwsA(isA<PrinterFailure>()),
        );
      }
      expect(network.validationError, isNull);
    },
  );

  test(
    'receipt uses stored discounted amounts without changing employee commission base',
    () {
      final saved = receipt();
      final before = jsonEncode(saved.bill.toJson());
      final rows = receiptRows(saved);
      expect(
        rows.firstWhere((row) => row.text == 'Subtotal').value,
        'PKR 200.50',
      );
      expect(
        rows.firstWhere((row) => row.text == 'Discount').value,
        '-PKR 20.00',
      );
      expect(rows.firstWhere((row) => row.text == 'TOTAL').value, 'PKR 211.19');
      expect(
        rows.any(
          (row) => row.text == '2 × PKR 100.25' && row.value == 'PKR 200.50',
        ),
        isTrue,
      );
      expect(saved.bill.commissionBase, 200.50);
      expect(jsonEncode(saved.bill.toJson()), before);
    },
  );

  test(
    'unconfigured receipt directs to Business Settings without calling hardware',
    () async {
      final hardware = FakeHardware();
      addTearDown(hardware.scan.close);
      final store = ReceiptPrinterStore(
        actions: ReceiptPrinterActions(LocalPrinterPreferences(), hardware),
        scope: () => 'owner/shop',
      );
      addTearDown(store.dispose);
      expect(await store.print(receipt()), isNull);
      expect(store.error, contains('Business Settings'));
      expect(hardware.prints, 0);
    },
  );

  test(
    'concurrent receipts are blocked, cancellation is distinct, failures never retry',
    () async {
      final hardware = FakeHardware();
      addTearDown(hardware.scan.close);
      final store = ReceiptPrinterStore(
        actions: ReceiptPrinterActions(LocalPrinterPreferences(), hardware),
        scope: () => 'owner/shop',
      );
      addTearDown(store.dispose);
      await store.save(system);
      hardware.pending = Completer();
      final first = store.print(receipt());
      while (hardware.prints == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await store.print(receipt()), isNull);
      expect(hardware.prints, 1);
      hardware.pending!.complete(ReceiptPrintResult.cancelled);
      expect(await first, ReceiptPrintResult.cancelled);
      expect(store.message, 'Printing cancelled.');
      hardware.pending = null;
      hardware.failure = const PrinterFailure(
        'Receipt may have printed. Check before reprinting.',
      );
      expect(await store.print(receipt()), isNull);
      expect(hardware.prints, 2);
      expect(store.busy, isFalse);
      expect(store.error, contains('may have printed'));
    },
  );

  test(
    'changing signed-in account cannot reuse another account printer',
    () async {
      final hardware = FakeHardware();
      addTearDown(hardware.scan.close);
      var scope = 'owner/shop';
      final store = ReceiptPrinterStore(
        actions: ReceiptPrinterActions(LocalPrinterPreferences(), hardware),
        scope: () => scope,
      );
      addTearDown(store.dispose);
      await store.save(network);
      scope = 'manager/shop';
      expect(await store.print(receipt()), isNull);
      expect(hardware.prints, 0);
      await store.save(system);
      expect(await store.print(receipt()), ReceiptPrintResult.sent);
      expect(hardware.lastConfig!.connection, ReceiptConnection.system);
    },
  );

  testWidgets(
    'thermal encoding and multipage system PDF render without hardware',
    (tester) async {
      final encoder = FlutterReceiptEncoder();
      final output = await tester.runAsync(() async {
        final config = File('.dart_tool/package_config.json').absolute;
        final packages =
            jsonDecode(await config.readAsString()) as Map<String, dynamic>;
        final flutter = (packages['packages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((package) => package['name'] == 'flutter');
        final sdk = Directory.fromUri(
          config.uri.resolve(flutter['rootUri'] as String),
        ).parent.parent;
        await (FontLoader('sans-serif')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    '${sdk.path}/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                  ).readAsBytes(),
                ),
              ),
            ))
            .load();
        final bytes = await encoder.thermal(receipt(), network);
        final document = await encoder.pdf(receipt(items: 80));
        if (const bool.fromEnvironment('EXPORT_PRINTER_REVIEW')) {
          await exportThermalPreview(bytes);
        }
        return (bytes: bytes, pdf: document);
      });
      expect(output!.bytes.take(2), [27, 64]);
      expect(output.bytes, containsAllInOrder([29, 118, 48]));
      expect(ascii.decode(output.pdf.take(5).toList()), '%PDF-');
      final raw = latin1.decode(output.pdf);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(1));
    },
  );

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('printer settings save, test and reset at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      if (const bool.fromEnvironment('EXPORT_PRINTER_REVIEW')) {
        await tester.runAsync(loadReviewFonts);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hardware = FakeHardware();
      addTearDown(hardware.scan.close);
      final store = ReceiptPrinterStore(
        actions: ReceiptPrinterActions(LocalPrinterPreferences(), hardware),
        scope: () => 'owner/shop',
      );
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider<BusinessProfileNotifier>(
              create: (_) => FakeProfile(),
            ),
            ChangeNotifierProvider<SettingsStore>(
              create: (_) => FakeSettings(),
            ),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.light(),
              debugShowCheckedModeBanner: false,
              home: const PrinterSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save printer'));
      await tester.tap(find.text('Save printer'));
      await tester.pumpAndSettle();
      expect(store.config!.connection, ReceiptConnection.system);
      await tester.ensureVisible(find.text('Print test receipt'));
      await tester.tap(find.text('Print test receipt'));
      await tester.pumpAndSettle();
      expect(hardware.prints, 1);
      expect(hardware.lastReceipt!.test, isTrue);
      expect(hardware.lastReceipt!.businessName, 'Test Salon');
      await tester.ensureVisible(find.text('Remove saved printer'));
      await tester.tap(find.text('Remove saved printer'));
      await tester.pumpAndSettle();
      expect(store.config, isNull);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_PRINTER_REVIEW')) {
        await tester.tap(
          find.byType(DropdownButtonFormField<ReceiptConnection>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ReceiptConnection.network.label).last);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final view =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await view.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/printer-review/settings-${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('checkout receipt prints the saved bill and preserves sharing', (
    tester,
  ) async {
    final hardware = FakeHardware();
    addTearDown(hardware.scan.close);
    final store = ReceiptPrinterStore(
      actions: ReceiptPrinterActions(LocalPrinterPreferences(), hardware),
      scope: () => 'manager/shop',
    );
    addTearDown(store.dispose);
    await store.save(network);
    final saved = receipt().bill;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider<BusinessProfileNotifier>(
            create: (_) => FakeProfile(),
          ),
          ChangeNotifierProvider<SettingsStore>(create: (_) => FakeSettings()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              bill: saved,
              business: const ReceiptBusinessInfo(
                name: 'Test Salon',
                phone: '',
                address: '',
              ),
              currency: 'PKR',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Share receipt'), findsOneWidget);
    await tester.tap(find.text('Print receipt'));
    await tester.pumpAndSettle();
    expect(hardware.lastReceipt!.bill, same(saved));
    expect(hardware.lastReceipt!.test, isFalse);
    expect(hardware.prints, 1);
    expect(find.text('Business Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
