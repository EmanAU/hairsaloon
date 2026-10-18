import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hairsaloon/src/features/dashboard/presentation/dashboard_shell.dart';
import 'package:hairsaloon/src/online/data/business_workspace.dart';
import 'package:hairsaloon/src/online/domain/online_repository.dart';
import 'package:hairsaloon/src/features/services/data/repositories/hive_services_repository.dart';

final _directories = <WidgetTester, Directory>{};

Future<void> prepareOnlineWorkspace(WidgetTester tester) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('online_dashboard_'),
  ))!;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => directory.path,
  );
  SharedPreferences.setMockInitialValues({});
  _directories[tester] = directory;
}

Future<void> closeOnlineWorkspace(WidgetTester tester) async {
  var closed = false;
  Hive.close().then((_) => closed = true);
  for (var i = 0; i < 100 && !closed; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(closed, isTrue);
  final directory = _directories.remove(tester);
  if (directory != null) {
    await tester.runAsync(() => directory.delete(recursive: true));
  }
}

Future<void> preopenOnlineWorkspace(
  WidgetTester tester,
  OnlineRepository repository,
) async {
  final account = await repository.loadWorkspace();
  final workspace = await tester.runAsync(() async {
    final workspace = await BusinessWorkspace.open(
      repository,
      account.businesses.firstWhere((business) => business.isActive),
      account.account,
    );
    await HiveServicesRepository(
      servicesBox: workspace.maps['services'],
      categoriesBox: workspace.maps['categories'],
    ).ensureSeeded();
    return workspace;
  });
  workspace!.dispose();
}

Future<void> waitForOnlineDashboard(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(DashboardShell).evaluate().isNotEmpty) break;
  }
  expect(find.byType(DashboardShell), findsOneWidget);
  await tester.pumpAndSettle();
}
