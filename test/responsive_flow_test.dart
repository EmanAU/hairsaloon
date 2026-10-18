import 'dart:convert';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_details_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_history_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_details_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_analytics_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/all_expenses_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/employee_workings_screen.dart';
import 'package:hairsaloon/src/features/expenses/domain/entities/expense_item.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_income_detail_screen.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/finance_period.dart';
import 'package:hairsaloon/src/features/services/presentation/service_details_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategory_services_screen.dart';
import 'package:hairsaloon/src/features/customers/presentation/customer_history_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/create_bill_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:hairsaloon/src/app.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/data/repositories/local_auth_repository.dart';
import 'package:hairsaloon/src/features/business_profile/data/repositories/shared_prefs_business_profile_repository.dart';
import 'package:hairsaloon/src/features/business_profile/domain/entities/business_profile.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/core/storage/hive_bootstrap.dart';
import 'package:hairsaloon/src/features/billing/data/repositories/hive_billing_repository.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/services/data/repositories/hive_services_repository.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';

void main() {
  for (final entry in <String, Size>{
    'mobile': const Size(390, 844),
    'tablet_portrait': const Size(800, 1280),
    'tablet_landscape': const Size(1280, 800),
  }.entries) {
    testWidgets(
      '${entry.key}: complete named route flow has no layout exceptions',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          debugDefaultTargetPlatformOverride = null;
        });
        final temp = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('salon-responsive-'),
        ))!;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await LocalAuthRepository(
          prefs: prefs,
          session: LocalAuthSessionDataSource(prefs: prefs),
        ).registerUser(
          name: 'Ali Khan',
          phone: '+923001234567',
          password: 'demo1234',
        );
        await SharedPrefsBusinessProfileRepository(prefs: prefs).saveProfile(
          const BusinessProfile(
            businessName: 'Business COMB Salon',
            phoneNumber: '+923001234567',
            businessType: 'Hair Salon',
            city: 'Islamabad',
            area: 'G-11',
            address: 'G-11 Markaz, Islamabad',
          ),
        );
        await tester.runAsync(() async {
          await HiveBootstrap.init(prefs);
          await HiveEmployeesRepository().add(
            const EmployeeItem(
              id: 'preview-employee',
              firstName: 'Ali',
              lastName: '',
              phoneNumber: '+923001234567',
              cnicNumber: '35202-1234567-1',
              homeAddress: 'G-11 Markaz, Islamabad',
              isActive: true,
              commission: '10',
            ),
          );
          await HiveExpensesRepository().add(
            ExpenseItem(
              id: 'preview-expense',
              date: DateTime.now(),
              employeeName: 'Ali',
              amount: 100,
              status: 'Paid',
              paymentType: 'Cash',
              expenseType: 'Tea/Coffee',
              quantity: 1,
              description: 'Test expense',
              createdAt: DateTime.now(),
            ),
          );
          await ServicesStore(repository: HiveServicesRepository()).load();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await HiveBillingRepository().saveBill(
            Bill(
              id: 'preview-bill',
              createdAt: DateTime.now(),
              customerName: 'Ahmed',
              customerPhone: '+923009876543',
              employeeName: 'Ali',
              paymentType: 'Cash',
              lines: const [BillLine(serviceName: 'Haircut', price: 800)],
              subTotal: 800,
              taxPercent: 0,
              taxAmount: 0,
              grandTotal: 800,
            ),
          );
          {
            final configFile = File('.dart_tool/package_config.json').absolute;
            final config =
                jsonDecode(await configFile.readAsString())
                    as Map<String, dynamic>;
            final flutterPackage = (config['packages'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((p) => p['name'] == 'flutter');
            final sdk = Directory.fromUri(
              configFile.uri.resolve(flutterPackage['rootUri'] as String),
            ).parent.parent;
            final fontDir = '${sdk.path}/bin/cache/artifacts/material_fonts';
            for (final name in ['regular', 'medium', 'bold']) {
              final loader = FontLoader('Roboto')
                ..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('$fontDir/roboto-$name.ttf').readAsBytes(),
                    ),
                  ),
                );
              await loader.load();
            }
            final fallback = FontLoader('Ahem')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('$fontDir/roboto-regular.ttf').readAsBytes(),
                  ),
                ),
              );
            await fallback.load();
            final material = FontLoader('MaterialIcons')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '$fontDir/materialicons-regular.otf',
                    ).readAsBytes(),
                  ),
                ),
              );
            await material.load();
            final cupertino =
                FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
                  rootBundle.load(
                    'packages/cupertino_icons/assets/CupertinoIcons.ttf',
                  ),
                );
            await cupertino.load();
          }
        });
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: const BusinessCombApp()),
        );
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          if (ToastService.navigatorKey.currentState != null) break;
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'bootstrap ${entry.key}',
        );

        Future<void> capture(String name) async {
          debugPrint("Capturing ${entry.key}/$name");
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 120)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$name ${entry.key}');
          if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('screenshots/${entry.key}');
              await directory.create(recursive: true);
              await File(
                '${directory.path}/$name.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }

        await capture('01_dashboard');
        // Home must show saved business details and the actual daily ledger.
        expect(find.text('Business COMB Salon'), findsOneWidget);
        expect(find.text('PKR 800.00'), findsOneWidget);

        final rail = find.byType(NavigationRail);
        expect(rail, entry.key == 'mobile' ? findsNothing : findsOneWidget);
        Finder navItem(String label) => entry.key == 'mobile'
            ? find.byTooltip(label)
            : find.text(label).last;
        await tester.tap(navItem('Billing'));
        await capture('02_billing');
        expect(
          find.text('New Ticket'),
          entry.key == 'mobile' ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const ValueKey('checkout-employee')), findsNothing);
        if (entry.key == 'tablet_landscape') {
          await tester.tap(find.text('Simple Cutting').first);
          await tester.tap(find.text('Kids Hair Cut').first);
          await tester.pumpAndSettle();
          expect(find.text('2 Items'), findsOneWidget);
          await tester.tap(find.text('Discount').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Percentage (%)'));
          await tester.enterText(
            find.widgetWithText(TextField, 'Discount percentage'),
            '10',
          );
          await tester.tap(find.text('Apply'));
          await tester.pumpAndSettle();
          expect(find.text('-Rs 90'), findsOneWidget);
          await capture('02_billing_order');
          tester.view.physicalSize = const Size(1024, 600);
          await capture('02_billing_small_tablet');
          await tester.tap(find.text('Search').first);
          await tester.pumpAndSettle();
          await tester.showKeyboard(
            find.byKey(const ValueKey('customer-search')),
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          await capture('02_billing_keyboard');
          tester.view.resetViewInsets();
          tester.testTextInput.hide();
          tester.view.physicalSize = entry.value;
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('customer-search')),
            '+923009876543',
          );
          await tester.pumpAndSettle();
          expect(find.text('Ahmed'), findsOneWidget);
          await capture('02_customer_found');
          await tester.enterText(
            find.byKey(const ValueKey('customer-search')),
            '03412541658',
          );
          await tester.pumpAndSettle();
          expect(find.text('Add New Customer'), findsOneWidget);
          await capture('02_customer_new');
          await tester.tap(find.text('Walk-in').first);
          await tester.tap(find.text('Checkout'));
          await tester.pumpAndSettle();
          await capture('02_checkout_modal');
          await tester.tap(find.text('Save & show receipt'));
          await tester.pumpAndSettle();
          expect(find.text('Select employee'), findsOneWidget);
          expect(find.text('Select payment method'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('checkout-employee')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ali').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('checkout-payment')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cash').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save & show receipt'));
          for (
            var attempt = 0;
            attempt < 30 && find.text('Receipt saved').evaluate().isEmpty;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle();
          expect(find.text('Receipt saved'), findsOneWidget);
          final saved = ToastService.navigatorKey.currentContext!
              .read<BillingStore>()
              .bills
              .firstWhere((bill) => bill.id != 'preview-bill');
          expect(saved.grandTotal, closeTo(947.7, .001));
          expect(saved.customerPhone, isEmpty);
          await capture('02_receipt_modal');
          await tester.tap(find.text('Detailed receipt'));
          await tester.pumpAndSettle();
          expect(find.text('Bill Details'), findsOneWidget);
          ToastService.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          expect(find.text('0 Items'), findsOneWidget);
        }
        await tester.tap(navItem('Expense'));
        await capture('03_expenses');
        await tester.tap(navItem('Home'));
        if (entry.key != 'mobile') {
          await tester.tap(find.byTooltip('Open menu').first);
        }
        // Mobile uses the header menu icon instead of the tablet rail button.
        if (entry.key == 'mobile') {
          final scaffold = tester.state<ScaffoldState>(
            find.byType(Scaffold).first,
          );
          scaffold.openDrawer();
        }
        await capture('04_menu');
        ToastService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        final routes = <String, String>{
          '05_login': AppRoutes.login,
          '06_phone_login': AppRoutes.phonePasswordLogin,
          '07_register': AppRoutes.register,
          '08_business_registration': AppRoutes.businessRegistration,
          '09_employees': AppRoutes.employees,
          '10_employee_agreement': AppRoutes.employeeAgreement,
          '11_services': AppRoutes.serviceList,
          '12_new_service': AppRoutes.newService,
          '13_categories': AppRoutes.categories,
          '14_subcategories': AppRoutes.subcategories,
          '15_finance': AppRoutes.financeOverview,
          '16_employee_earnings': AppRoutes.employeeEarnings,
          '17_sales': AppRoutes.financeSales,
          '18_expense_types': AppRoutes.expenseTypes,
          '19_customers': AppRoutes.customers,
          '20_profile_settings': AppRoutes.profileSettings,
          '21_account_profile': AppRoutes.accountProfile,
          '22_saved_bills': AppRoutes.savedBills,
          '23_bill_details': AppRoutes.billDetails,
          '24_appointments': AppRoutes.appointments,
          '25_receipt_view': AppRoutes.receiptView,
        };
        for (final route in routes.entries) {
          ToastService.navigatorKey.currentState!.pushNamed(
            route.value,
            arguments:
                route.value == AppRoutes.billDetails ||
                    route.value == AppRoutes.receiptView
                ? 'preview-bill'
                : null,
          );
          await capture(route.key);
          ToastService.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
        }
        final ctx = ToastService.navigatorKey.currentContext!;
        final employee = ctx.read<EmployeesStore>().employees.first;
        final expense = ctx.read<ExpensesStore>().items.first;
        final service = ctx.read<ServicesStore>().services.first;
        final bills = ctx.read<BillingStore>().bills;
        final details = <String, Widget>{
          '26_employee_details': EmployeeDetailsScreen(item: employee),
          '27_employee_history': EmployeeHistoryScreen(
            employee: employee,
            bills: bills,
          ),
          '28_employee_income': EmployeeIncomeDetailScreen(
            employee: employee,
            period: FinancePeriod.monthly,
            anchorDate: DateTime.now(),
          ),
          '29_employee_workings': EmployeeWorkingsScreen(
            employee: employee,
            period: WorkingsPeriod.monthly,
            anchorDate: DateTime.now(),
          ),
          '30_all_expenses': const AllExpensesScreen(),
          '31_expense_details': ExpenseDetailsScreen(itemId: expense.id),
          '32_expense_analytics': ExpenseAnalyticsScreen(
            items: ctx.read<ExpensesStore>().items,
          ),
          '33_service_details': ServiceDetailsScreen(item: service),
          '34_subcategory_services': SubcategoryServicesScreen(
            category: service.category,
            subcategory: service.subcategory,
          ),
          '35_customer_history': CustomerHistoryScreen(
            customerLabel: 'Ahmed',
            bills: bills,
          ),
          '36_create_bill': const CreateBillScreen(
            customerName: 'Ahmed',
            customerPhone: '+923009876543',
          ),
        };
        for (final detail in details.entries) {
          ToastService.navigatorKey.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => detail.value),
          );
          await capture(detail.key);
          ToastService.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
        }
        ToastService.navigatorKey.currentState!.pushNamed(AppRoutes.register);
        await tester.pumpAndSettle();
        await tester.showKeyboard(find.byType(TextFormField).first);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await capture('37_register_keyboard');
        tester.view.resetViewInsets();
        tester.testTextInput.hide();
        ToastService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        ToastService.navigatorKey.currentState!.pushNamed(
          AppRoutes.expenseTypes,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select Date').first);
        await capture('38_expense_date_picker');
        ToastService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        ToastService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        ToastService.success('Bill saved successfully');
        await capture('25_notification');
        await tester.tap(find.byTooltip('Dismiss notification'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
        var closed = false;
        Hive.close().then((_) => closed = true);
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(closed, isTrue, reason: 'local storage closes after rendering');
        await tester.runAsync(() => temp.delete(recursive: true));
      },
    );
  }
}
