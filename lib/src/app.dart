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
import 'package:hairsaloon/src/features/billing/presentation/receipt_view_screen.dart';
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
import 'package:hairsaloon/src/features/expenses/presentation/expense_history_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expense_types_screen.dart';
import 'package:hairsaloon/src/features/expenses/presentation/state/expenses_store.dart';
import 'package:hairsaloon/src/features/expenses/presentation/expenses_screen.dart';
import 'package:hairsaloon/src/features/finance/data/repositories/hive_payouts_repository.dart';
import 'package:hairsaloon/src/features/finance/presentation/employee_earnings_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_expenses_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/profit_detail_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/state/payouts_store.dart';
import 'package:hairsaloon/src/features/finance/presentation/finance_overview_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/sales_screen.dart';
import 'package:hairsaloon/src/features/finance/presentation/settled_salaries_screen.dart';
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
import 'package:hairsaloon/src/theme/app_colors.dart';
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
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
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
                // Needed immediately for session → home / login routing.
                ChangeNotifierProvider<BusinessProfileNotifier>.value(
                  value: bootstrap.profileNotifier,
                ),
                ChangeNotifierProvider<AuthStore>.value(
                  value: bootstrap.authStore,
                ),
                // Created on first use (lazy) so splash stays light.
                ChangeNotifierProvider<BillingStore>(
                  create: (_) =>
                      BillingStore(repository: HiveBillingRepository()),
                ),
                ChangeNotifierProvider<EmployeesStore>(
                  create: (_) =>
                      EmployeesStore(repository: HiveEmployeesRepository()),
                ),
                ChangeNotifierProvider<ExpensesStore>(
                  create: (_) =>
                      ExpensesStore(repository: HiveExpensesRepository()),
                ),
                ChangeNotifierProvider<PayoutsStore>(
                  create: (_) =>
                      PayoutsStore(repository: HivePayoutsRepository()),
                ),
                ChangeNotifierProvider<ServicesStore>(
                  create: (_) =>
                      ServicesStore(repository: HiveServicesRepository()),
                ),
                ChangeNotifierProvider<SettingsStore>(
                  create: (_) => SettingsStore(
                    repository: HiveSettingsRepository(
                      accountId: () => bootstrap.authStore.currentUser?.id,
                    ),
                  ),
                ),
              ],
              child: _DeferredStoreWarmup(
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
                        AppRoutes.appointments: (_) =>
                            const AppointmentsScreen(),
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
                        AppRoutes.financeProfit: (_) =>
                            const ProfitDetailScreen(),
                        AppRoutes.financeExpenses: (_) =>
                            const FinanceExpensesScreen(),
                        AppRoutes.financeSalaries: (_) =>
                            const SettledSalariesScreen(),
                        AppRoutes.expenseTypes: (_) =>
                            const ExpenseTypesScreen(),
                        AppRoutes.expenses: (_) => const ExpensesScreen(),
                        AppRoutes.expenseHistory: (_) =>
                            const ExpenseHistoryScreen(),
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
                    if (settings.name == AppRoutes.receiptView) {
                      final billId = settings.arguments as String?;
                      if (billId == null) return null;
                      return MaterialPageRoute(
                        builder: (_) => AdaptivePage(
                          child: ReceiptViewScreen(billId: billId),
                        ),
                      );
                    }
                    return null;
                  },
                ),
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

  /// Only what splash needs to decide login vs home.
  /// Billing / employees / services / settings are created lazily by Provider.
  Future<_AppBootstrap> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    await HiveBootstrap.init(prefs);

    final repository = SharedPrefsBusinessProfileRepository(prefs: prefs);
    await repository.migrateLegacyProfile();
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
      onSessionChanged: profileNotifier.load,
    );

    final hasAuthSession = await authStore.hasLocalSession();
    if (hasAuthSession) {
      await authStore.loadCurrentUser();
    }

    return _AppBootstrap(
      profileNotifier: profileNotifier,
      authStore: authStore,
      hasAuthSession: hasAuthSession,
      hasBusinessProfile: profileNotifier.profile != null,
    );
  }
}

class _AppBootstrap {
  const _AppBootstrap({
    required this.profileNotifier,
    required this.authStore,
    required this.hasAuthSession,
    required this.hasBusinessProfile,
  });

  final BusinessProfileNotifier profileNotifier;
  final AuthStore authStore;
  final bool hasAuthSession;
  final bool hasBusinessProfile;
}

/// Soft background warm-up after first frame — does not block splash/home.
class _DeferredStoreWarmup extends StatefulWidget {
  const _DeferredStoreWarmup({required this.child});

  final Widget child;

  @override
  State<_DeferredStoreWarmup> createState() => _DeferredStoreWarmupState();
}

class _DeferredStoreWarmupState extends State<_DeferredStoreWarmup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warm());
  }

  Future<void> _warm() async {
    if (!mounted) return;
    // Prefetch catalogue quietly so Rate List / Categories feel instant later.
    await context.read<ServicesStore>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Re-check live session so a saved login always opens Home until logout.
    final auth = context.read<AuthStore>();
    final profile = context.read<BusinessProfileNotifier>();

    var hasSession = widget.hasAuthSession || auth.currentUser != null;
    if (!hasSession) {
      hasSession = await auth.hasLocalSession();
    }
    if (hasSession && auth.currentUser == null) {
      await auth.loadCurrentUser();
      hasSession = auth.currentUser != null;
    }

    final hasProfile = widget.hasBusinessProfile || profile.profile != null;

    if (!mounted) return;
    final String next;
    if (!hasSession) {
      next = AppRoutes.login;
    } else if (!hasProfile) {
      next = AppRoutes.businessRegistration;
    } else {
      next = AppRoutes.homeShell;
    }
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Text(
          'Barber Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
