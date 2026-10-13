import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_agreement_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/widgets/service_edit_sheet.dart';
import 'package:hairsaloon/src/features/finance/data/repositories/hive_payouts_repository.dart';
import 'package:hairsaloon/src/features/finance/domain/entities/salary_payout.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/widgets/settle_salary_dialog.dart';
import 'package:hairsaloon/src/features/finance/domain/finance_calculator.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/core/storage/hive_bootstrap.dart';
import 'package:hairsaloon/src/features/billing/data/repositories/hive_billing_repository.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/services/data/repositories/hive_services_repository.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';

class _ReviewImagePicker extends ImagePickerPlatform {
  _ReviewImagePicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(bytes, name: 'review-shop-logo.png');
  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

class _OfflineHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw StateError(
    'HTTP networking is disabled during the portrait audit.',
  );
}

void main() {
  for (final entry in <String, Size>{
    'tablet/galaxy_tab_a9_plus': const Size(800, 1280),
    'tablet/compact_600': const Size(600, 960),
    'tablet/large_960': const Size(960, 1536),
    'mobile/standard_390': const Size(390, 844),
    'mobile/compact_320': const Size(320, 640),
    'mobile/large_430': const Size(430, 932),
  }.entries) {
    testWidgets('${entry.key}: portrait flow audit', (tester) async {
      final previousHttp = HttpOverrides.current;
      HttpOverrides.global = _OfflineHttp();
      addTearDown(() => HttpOverrides.global = previousHttp);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final tablet = entry.key.startsWith('tablet/');
      final density = tablet ? 1.5 : 1.0;
      tester.view.physicalSize = entry.value * density;
      tester.view.devicePixelRatio = density;
      tester.view.padding = FakeViewPadding(
        top: 24 * density,
        bottom: 24 * density,
      );
      tester.view.viewPadding = FakeViewPadding(
        top: 24 * density,
        bottom: 24 * density,
      );
      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetViewPadding();
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
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.image_picker_android.ImagePickerApi.retrieveLostResults',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.image_picker_android.ImagePickerApi.pickImages',
        (_) async => const StandardMessageCodec().encodeMessage([
          [File('assets/logo.png').absolute.path],
        ]),
      );
      final previousPicker = ImagePickerPlatform.instance;
      final logoBytes = (await tester.runAsync(
        () => File('assets/logo.png').readAsBytes(),
      ))!;
      ImagePickerPlatform.instance = _ReviewImagePicker(logoBytes);
      addTearDown(() => ImagePickerPlatform.instance = previousPicker);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
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
            basicSalary: '30000',
            agreementDescription: 'Monthly salary plus service commission.',
          ),
        );
        await HiveEmployeesRepository().add(
          const EmployeeItem(
            id: 'preview-manager',
            firstName: 'Sana',
            lastName: 'Khan',
            phoneNumber: '+923001111222',
            cnicNumber: '35202-1234567-2',
            homeAddress: 'Islamabad',
            isActive: true,
          ),
        );
        await HivePayoutsRepository().saveAll([
          SalaryPayout(
            id: 'preview-payout',
            employeeId: 'preview-employee',
            employeeName: 'Ali',
            workDate: DateTime.now(),
            amount: 50,
            settledAt: DateTime.now(),
            note: 'Sample settled salary',
          ),
        ]);
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
      void resolveAndroidFonts(Element element) {
        final widget = element.widget;
        if (widget is Text && widget.style?.fontFamily == null) {
          // Flutter's test engine substitutes Ahem for unnamed fonts. Resolve
          // those to Android's Roboto without changing the production widgets.
          final style = (widget.style ?? const TextStyle()).copyWith(
            fontFamily: 'Roboto',
          );
          final text = widget.data != null
              ? Text(
                  widget.data!,
                  key: widget.key,
                  style: style,
                  textAlign: widget.textAlign,
                  textDirection: widget.textDirection,
                  locale: widget.locale,
                  softWrap: widget.softWrap,
                  overflow: widget.overflow,
                  textScaler: widget.textScaler,
                  maxLines: widget.maxLines,
                  semanticsLabel: widget.semanticsLabel,
                  textWidthBasis: widget.textWidthBasis,
                  textHeightBehavior: widget.textHeightBehavior,
                )
              : Text.rich(
                  widget.textSpan!,
                  key: widget.key,
                  style: style,
                  textAlign: widget.textAlign,
                  textDirection: widget.textDirection,
                  locale: widget.locale,
                  softWrap: widget.softWrap,
                  overflow: widget.overflow,
                  textScaler: widget.textScaler,
                  maxLines: widget.maxLines,
                  semanticsLabel: widget.semanticsLabel,
                  textWidthBasis: widget.textWidthBasis,
                  textHeightBehavior: widget.textHeightBehavior,
                );
          element.update(text);
        }
        element.visitChildren(resolveAndroidFonts);
      }

      final issues = <Map<String, String>>[];
      final captures = <Map<String, dynamic>>[];
      var sequence = 0;
      Future<void> capture(String name) async {
        debugPrint("Capturing ${entry.key}/$name");
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pumpAndSettle();
        tester.binding.buildOwner!.buildScope(tester.binding.rootElement!, () {
          tester.binding.rootElement!.visitChildren(resolveAndroidFonts);
        });
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error != null) {
          issues.add({'screen': name, 'error': error.toString()});
        }
        final label = name.replaceFirst(RegExp(r'^\d+_'), '');
        final filename =
            '${(++sequence).toString().padLeft(3, '0')}_$label.png';
        captures.add({
          'screen': name,
          'file': filename,
          'logicalWidth': entry.value.width,
          'logicalHeight': entry.value.height,
        });
        if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: density);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory(
              'screenshots/${entry.key.replaceFirst('tablet/', 'tablet_review/').replaceFirst('mobile/', 'mobile_review/')}',
            );
            await directory.create(recursive: true);
            await File(
              '${directory.path}/$filename',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      Future<void> pages(String name) async {
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        if (vertical.evaluate().isEmpty) return;
        final scrollable = tester.state<ScrollableState>(vertical.first);
        for (
          var page = 1;
          page <= 8 &&
              scrollable.position.pixels <
                  scrollable.position.maxScrollExtent - 2;
          page++
        ) {
          await tester.drag(
            vertical.first,
            Offset(0, -entry.value.height * 0.6),
          );
          await capture('${name}_scroll_$page');
        }
      }

      Future<void> press(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.35);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> openDrawer() async {
        if (tablet) {
          await press(find.byTooltip('Open menu').first);
        } else {
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
          await tester.pumpAndSettle();
        }
      }

      await capture('00_splash');
      await tester.pump(const Duration(seconds: 3));
      await capture('01_auth_selection');
      await press(find.text('Register').last);
      await capture('02_registration_empty');
      await press(find.widgetWithText(ElevatedButton, 'Register'));
      await capture('03_registration_validation');
      const phone = String.fromEnvironment(
        'QA_PHONE',
        defaultValue: '+923451234567',
      );
      const password = String.fromEnvironment(
        'QA_PASSWORD',
        defaultValue: 'review1234',
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Portrait Review');
      await tester.enterText(fields.at(1), phone);
      await tester.enterText(fields.at(2), password);
      await tester.enterText(fields.at(3), password);
      tester.testTextInput.hide();
      await capture('04_registration_filled');
      await pages('registration');
      await press(find.widgetWithText(ElevatedButton, 'Register'));
      await capture('05_business_setup_empty');
      await press(find.text('Add photo'));
      await capture('business_photo_source_dialog');
      await tester.tap(find.text('Choose from gallery'));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await capture('business_photo_selected');
      await press(find.text('Change photo'));
      await capture('business_photo_remove_dialog');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      final businessFields = find.byType(TextFormField);
      await tester.enterText(businessFields.at(0), 'Business COMB Salon');
      await tester.enterText(businessFields.at(2), 'Islamabad');
      await tester.enterText(businessFields.at(3), 'G-11');
      await tester.enterText(businessFields.at(4), 'G-11 Markaz, Islamabad');
      tester.testTextInput.hide();
      await capture('06_business_setup_filled');
      await pages('business_setup');
      await press(find.text('Save & continue'));
      await capture('07_dashboard_after_registration');
      await openDrawer();
      await capture('08_drawer_initial');
      await press(find.text('Logout').last);
      await capture('09_logout_confirmation');
      await press(find.text('Logout').last);
      await capture('10_logged_out');
      await press(find.text('Login').last);
      await capture('11_login_empty');
      await press(find.widgetWithText(ElevatedButton, 'Login'));
      await capture('login_validation');
      await tester.enterText(find.byType(TextFormField).at(0), phone);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      tester.testTextInput.hide();
      await capture('12_login_filled');
      await press(find.widgetWithText(ElevatedButton, 'Login'));
      await capture('13_dashboard_after_login');
      final authenticated = ToastService.navigatorKey.currentContext!
          .read<AuthStore>();
      expect(authenticated.currentUser?.phone, phone);
      await capture('01_dashboard');
      final rail = find.byType(NavigationRail);
      expect(rail, !tablet ? findsNothing : findsOneWidget);
      Finder navItem(String label) =>
          !tablet ? find.byTooltip(label) : find.text(label).last;
      await tester.tap(navItem('Billing'));
      await capture('02_billing');
      await press(find.text('Add New'));
      await capture('billing_add_customer_dialog');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await press(find.text('Discount'));
      await capture('billing_discount_dialog');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '+923009876543');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final useCustomer = find.text('Use Customer');
      if (useCustomer.evaluate().isNotEmpty) {
        await capture('billing_existing_customer_dialog');
        await press(useCustomer);
      }
      final serviceName = ToastService.navigatorKey.currentContext!
          .read<ServicesStore>()
          .services
          .first
          .subcategory;
      await press(find.text(serviceName).first);
      await capture('billing_service_selected');
      final billingDropdowns = find.byType(DropdownButtonFormField<String>);
      await press(billingDropdowns.first);
      await capture('billing_employee_dropdown');
      await press(find.text('Ali').last);
      await press(billingDropdowns.last);
      await capture('billing_payment_dropdown');
      await press(find.text('Cash').last);
      await capture('billing_ready_to_save');
      await press(find.text('Save Bill'));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await capture('billing_saved_bill_details');
      expect(
        ToastService.navigatorKey.currentContext!
            .read<BillingStore>()
            .bills
            .length,
        greaterThan(1),
      );
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(navItem('Expense'));
      await capture('03_expenses');
      await tester.tap(navItem('Home'));
      if (tablet) {
        await tester.tap(find.byTooltip('Open menu').first);
      }
      // Mobile uses the header menu icon instead of the tablet rail button.
      if (!tablet) {
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
        '39_employees_again': AppRoutes.employees,
        '40_expense_history': AppRoutes.expenseHistory,
        '41_profit_details': AppRoutes.financeProfit,
        '42_finance_expenses': AppRoutes.financeExpenses,
        '43_settled_salaries': AppRoutes.financeSalaries,
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
        await pages(route.key);
        if (route.value == AppRoutes.employees &&
            route.key == '09_employees') {
          final menus = find.byWidgetPredicate(
            (widget) =>
                widget is PopupMenuButton<String> &&
                widget.icon is Icon &&
                (widget.icon as Icon).size == 18,
          );
          if (menus.evaluate().isNotEmpty) {
            await press(menus.first);
            await capture('${route.key}_actions_menu');
            if (find.text('Assign').evaluate().isNotEmpty) {
              await press(find.text('Assign'));
              await capture('assign_employee_dialog');
              ToastService.navigatorKey.currentState!.pop();
            } else {
              await press(find.text('Delete'));
              await capture('employee_delete_confirmation');
              ToastService.navigatorKey.currentState!.pop();
            }
            await tester.pumpAndSettle();
          }
        }

        if (route.value == AppRoutes.employees &&
            route.key == '09_employees') {
          final add = find.byIcon(CupertinoIcons.add);
          if (add.evaluate().isNotEmpty) {
            await press(add.first);
            await capture('${route.key}_add_form');
            if (find.text('Add photo').evaluate().isNotEmpty) {
              await press(find.text('Add photo'));
              await capture('${route.key}_photo_source_dialog');
              ToastService.navigatorKey.currentState!.pop();
              await tester.pumpAndSettle();
            }
            await pages('${route.key}_add_form');
          }
        }
        if (route.value == AppRoutes.categories) {
          final menus = find.byType(PopupMenuButton<String>);
          if (menus.evaluate().isNotEmpty) {
            await press(menus.first);
            await capture('category_actions_menu');
            await press(find.text('Rename'));
            await capture('category_rename_dialog');
            ToastService.navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
            await press(menus.first);
            await press(find.text('Delete'));
            await capture('category_delete_confirmation');
            ToastService.navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
          }

          await press(find.byTooltip('Add category'));
          await capture('category_add_dialog');
          ToastService.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
        }
        if (route.value == AppRoutes.subcategories) {
          final add = find.byIcon(CupertinoIcons.add);
          if (add.evaluate().isNotEmpty) {
            await press(add.first);
            await capture('subcategory_add_form');
            await pages('subcategory_add_form');
          }
        }
        if (route.value == AppRoutes.profileSettings) {
          await press(find.text('Edit'));
          await capture('profile_edit');
          await pages('profile_edit');
        }
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
        'employee_agreement_filled': EmployeeAgreementScreen(
          employee: employee,
        ),
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
        await pages(detail.key);
        final edit = find.text('Edit');
        if (edit.evaluate().isNotEmpty) {
          await press(edit.first);
          await capture('${detail.key}_edit');
          await pages('${detail.key}_edit');
        }
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
      ToastService.navigatorKey.currentState!.pushNamed(AppRoutes.expenseTypes);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select Date').first);
      await capture('38_expense_date_picker');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      for (final item in ['Tax Rate', 'Currency Change']) {
        await openDrawer();
        await pages('drawer_full_menu');
        await press(find.text(item));
        await capture('${item.toLowerCase().replaceAll(' ', '_')}_dialog');
        ToastService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
      }
      final shellContext = find.byType(NavigationRail).evaluate().isNotEmpty
          ? find.byType(NavigationRail).evaluate().first
          : find.byType(Scaffold).evaluate().first;
      showSettleSalaryDialog(
        context: shellContext,
        employeeName: employee.fullName,
        days: [
          EmployeeDayIncome(
            date: DateTime.now(),
            sales: 800,
            earning: 80,
            expenseCut: 0,
            payableAmount: 80,
            payout: null,
          ),
        ],
      );
      await capture('settle_salary_dialog');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      showServiceEditSheet(
        context: shellContext,
        title: 'Edit Service',
        nameLabel: 'Service name',
        name: service.subcategory,
        price: service.price,
      );
      await capture('service_edit_dialog');
      ToastService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      ToastService.success('Bill saved successfully');
      await capture('25_notification');
      await tester.tap(find.byTooltip('Dismiss notification'));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('EXPORT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final directory = Directory(
            'screenshots/${entry.key.replaceFirst('tablet/', 'tablet_review/').replaceFirst('mobile/', 'mobile_review/')}',
          );
          await directory.create(recursive: true);
          await File('${directory.path}/coverage.json').writeAsString(
            jsonEncode({
              'profile': entry.key,
              'portraitOnly': true,
              'renderSource':
                  'Flutter widget engine, Android styling; not a physical tablet',
              'captures': captures,
              'issues': issues,
            }),
          );
        });
      }
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
      expect(
        issues,
        isEmpty,
        reason: 'Portrait audit issues: ${jsonEncode(issues)}',
      );
    });
  }
}
