import 'package:hairsaloon/src/core/layout/adaptive_page.dart';
import 'package:hairsaloon/src/features/auth/data/repositories/local_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hairsaloon/src/features/auth/data/datasources/local_auth_session_datasource.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/has_session.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/login_with_phone_password.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/logout.dart';
import 'package:hairsaloon/src/features/auth/domain/usecases/register_user.dart';
import 'package:hairsaloon/src/features/auth/presentation/account_profile_screen.dart';
import 'package:hairsaloon/src/features/auth/presentation/auth_entry_screen.dart';
import 'package:hairsaloon/src/features/auth/presentation/phone_password_login_screen.dart';
import 'package:hairsaloon/src/features/auth/presentation/register_screen.dart';
import 'package:hairsaloon/src/features/auth/presentation/state/auth_store.dart';
import 'package:hairsaloon/src/core/storage/hive_bootstrap.dart';
import 'package:hairsaloon/src/features/appointments/presentation/appointments_screen.dart';
import 'package:hairsaloon/src/features/auth/presentation/business_registration_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/bill_details_screen.dart';
import 'package:hairsaloon/src/features/billing/presentation/saved_bills_screen.dart';
import 'package:hairsaloon/src/features/billing/data/repositories/hive_billing_repository.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/business_profile/data/repositories/shared_prefs_business_profile_repository.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/clear_business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/get_business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/domain/usecases/save_business_profile.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';
import 'package:hairsaloon/src/features/dashboard/presentation/dashboard_shell.dart';
import 'package:hairsaloon/src/features/customers/presentation/customers_screen.dart';
import 'package:hairsaloon/src/features/employees/data/repositories/hive_employees_repository.dart';
import 'package:hairsaloon/src/features/employees/presentation/employee_agreement_screen.dart';
import 'package:hairsaloon/src/features/employees/presentation/state/employees_store.dart';
import 'package:hairsaloon/src/features/employees/presentation/employees_screen.dart';
import 'package:hairsaloon/src/features/expenses/data/repositories/hive_expenses_repository.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_types_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expenses_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_earnings_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_overview_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/sales_screen.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/features/services/data/repositories/hive_services_repository.dart';
import 'package:hairsaloon/src/features/settings/presentation/profile_settings_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/features/settings/data/repositories/hive_settings_repository.dart';
import 'package:hairsaloon/src/features/settings/presentation/state/settings_store.dart';
import 'package:hairsaloon/src/features/services/presentation/new_service_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/categories_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/service_list_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/subcategories_screen.dart';
import 'package:hairsaloon/src/theme/app_theme.dart';
import 'package:hairsaloon/src/core/services/toast_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessCombApp extends StatefulWidget {
  const BusinessCombApp({super.key});

  @override
  State<BusinessCombApp> createState() => _BusinessCombAppState();
}

class _BusinessCombAppState extends State<BusinessCombApp> {
  late Future<_AppBootstrap> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    final size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    SystemChrome.setPreferredOrientations(
      size.shortestSide >= 600
          ? const []
          : const [DeviceOrientation.portraitUp],
    );
    _bootstrapFuture = _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      enableScaleWH: () =>
          MediaQueryData.fromView(View.of(context)).size.shortestSide < 600,
      enableScaleText: () =>
          MediaQueryData.fromView(View.of(context)).size.shortestSide < 600,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return FutureBuilder<_AppBootstrap>(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingApp();
            }

            if (snapshot.hasError) {
              return _errorApp(snapshot.error);
            }

            final bootstrap = snapshot.data;
            if (bootstrap == null) {
              return _loadingApp(message: 'Loading local storage...');
            }

            return MultiProvider(
              providers: [
                ChangeNotifierProvider<BusinessProfileNotifier>.value(
                  value: bootstrap.profileNotifier,
                ),
                ChangeNotifierProvider<BillingStore>.value(
                  value: bootstrap.billingStore,
                ),
                ChangeNotifierProvider<EmployeesStore>.value(
                  value: bootstrap.employeesStore,
                ),
                ChangeNotifierProvider<ExpensesStore>.value(
                  value: bootstrap.expensesStore,
                ),
                ChangeNotifierProvider<ServicesStore>.value(
                  value: bootstrap.servicesStore,
                ),
                ChangeNotifierProvider<SettingsStore>.value(
                  value: bootstrap.settingsStore,
                ),
                ChangeNotifierProvider<AuthStore>.value(
                  value: bootstrap.authStore,
                ),
              ],
              child: MaterialApp(
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(AppTheme.textScaleFactor),
                    ),
                    child: AdaptivePage(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
                title: 'Business COMB',
                debugShowCheckedModeBanner: false,
                navigatorKey: ToastService.navigatorKey,
                scaffoldMessengerKey: ToastService.messengerKey,
                theme: AppTheme.light(),
                initialRoute: AppRoutes.splash,
                routes:
                    <String, WidgetBuilder>{
                      AppRoutes.splash: (_) => SplashScreen(
                        hasBusinessProfile: bootstrap.hasBusinessProfile,
                        hasAuthSession: bootstrap.hasAuthSession,
                      ),
                      AppRoutes.login: (_) => const AuthEntryScreen(),
                      AppRoutes.phonePasswordLogin: (_) =>
                          const PhonePasswordLoginScreen(),
                      AppRoutes.register: (_) => const RegisterScreen(),
                      AppRoutes.businessRegistration: (_) =>
                          const BusinessRegistrationScreen(),
                      AppRoutes.homeShell: (_) => const DashboardShell(),
                      AppRoutes.appointments: (_) => const AppointmentsScreen(),
                      AppRoutes.employees: (_) => const EmployeesScreen(),
                      AppRoutes.employeeAgreement: (_) =>
                          const EmployeeAgreementScreen(),
                      AppRoutes.serviceList: (_) => const ServiceListScreen(),
                      AppRoutes.newService: (_) => const NewServiceScreen(),
                      AppRoutes.categories: (_) => const CategoriesScreen(),
                      AppRoutes.subcategories: (_) =>
                          const SubcategoriesScreen(),
                      AppRoutes.financeOverview: (_) =>
                          const FinanceOverviewScreen(),
                      AppRoutes.employeeEarnings: (_) =>
                          const EmployeeEarningsScreen(),
                      AppRoutes.financeSales: (_) => const SalesScreen(),
                      AppRoutes.expenseTypes: (_) => const ExpenseTypesScreen(),
                      AppRoutes.expenses: (_) => const ExpensesScreen(),
                      AppRoutes.customers: (_) => const CustomersScreen(),
                      AppRoutes.profileSettings: (_) =>
                          const ProfileSettingsScreen(),
                      AppRoutes.accountProfile: (_) =>
                          const AccountProfileScreen(),
                      AppRoutes.savedBills: (_) => const SavedBillsScreen(),
                    }.map(
                      (name, builder) => MapEntry(
                        name,
                        (context) => AdaptivePage(
                          form: {
                            AppRoutes.login,
                            AppRoutes.phonePasswordLogin,
                            AppRoutes.register,
                            AppRoutes.businessRegistration,
                            AppRoutes.newService,
                            AppRoutes.expenseTypes,
                            AppRoutes.accountProfile,
                            AppRoutes.profileSettings,
                            AppRoutes.employeeAgreement,
                          }.contains(name),
                          child: builder(context),
                        ),
                      ),
                    ),
                onGenerateRoute: (settings) {
                  if (settings.name == AppRoutes.billDetails) {
                    final billId = settings.arguments as String?;
                    if (billId == null) return null;
                    return MaterialPageRoute(
                      builder: (_) => AdaptivePage(
                        child: BillDetailsScreen(billId: billId),
                      ),
                    );
                  }
                  return null;
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _loadingApp({String message = 'Loading...'}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorApp(Object? error) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Failed to load local storage.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ?? 'Unknown error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _bootstrapFuture = _bootstrap();
                    });
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<_AppBootstrap> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    await HiveBootstrap.init(prefs);

    final billingStore = BillingStore(repository: HiveBillingRepository());
    final employeesStore = EmployeesStore(
      repository: HiveEmployeesRepository(),
    );
    final expensesStore = ExpensesStore(repository: HiveExpensesRepository());
    final servicesStore = ServicesStore(repository: HiveServicesRepository());
    await servicesStore.load();
    final settingsStore = SettingsStore(repository: HiveSettingsRepository());

    final repository = SharedPrefsBusinessProfileRepository(prefs: prefs);
    final profileNotifier = BusinessProfileNotifier(
      getBusinessProfile: GetBusinessProfile(repository),
      saveBusinessProfile: SaveBusinessProfile(repository),
      clearBusinessProfile: ClearBusinessProfile(repository),
    );
    await profileNotifier.load();

    final session = LocalAuthSessionDataSource(prefs: prefs);
    final authRepository = LocalAuthRepository(prefs: prefs, session: session);
    final authStore = AuthStore(
      hasSession: HasSession(authRepository),
      getCurrentUser: GetCurrentUser(authRepository),
      registerUser: RegisterUser(authRepository),
      loginWithPhonePassword: LoginWithPhonePassword(authRepository),
      logout: Logout(authRepository),
    );

    final hasAuthSession = await authStore.hasLocalSession();
    if (hasAuthSession) {
      await authStore.loadCurrentUser();
    }

    return _AppBootstrap(
      profileNotifier: profileNotifier,
      billingStore: billingStore,
      employeesStore: employeesStore,
      expensesStore: expensesStore,
      servicesStore: servicesStore,
      settingsStore: settingsStore,
      authStore: authStore,
      hasAuthSession: hasAuthSession,
      hasBusinessProfile: profileNotifier.profile != null,
    );
  }
}

class _AppBootstrap {
  const _AppBootstrap({
    required this.profileNotifier,
    required this.billingStore,
    required this.employeesStore,
    required this.expensesStore,
    required this.servicesStore,
    required this.settingsStore,
    required this.authStore,
    required this.hasAuthSession,
    required this.hasBusinessProfile,
  });

  final BusinessProfileNotifier profileNotifier;
  final BillingStore billingStore;
  final EmployeesStore employeesStore;
  final ExpensesStore expensesStore;
  final ServicesStore servicesStore;
  final SettingsStore settingsStore;
  final AuthStore authStore;
  final bool hasAuthSession;
  final bool hasBusinessProfile;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.hasAuthSession,
    required this.hasBusinessProfile,
  });

  final bool hasAuthSession;
  final bool hasBusinessProfile;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final next = widget.hasAuthSession
        ? (widget.hasBusinessProfile
              ? AppRoutes.homeShell
              : AppRoutes.businessRegistration)
        : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          'Barber Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
