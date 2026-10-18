import 'package:flutter/material.dart';
import '../core/layout/app_orientation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_online_repository.dart';
import 'domain/online_models.dart';
import 'online_app.dart';

Future<void> runOnlineApp(AppAudience audience) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureAppOrientation(business: audience == AppAudience.business);
  // Public client configuration; dart-defines can override it per environment.
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://djmncqhiugyanfkcxsqs.supabase.co',
  );
  const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ms2uGfWc5X_KOq5yR94irA_cs0m1WNu',
  );
  SupabaseOnlineRepository? repository;
  String? error;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      repository = SupabaseOnlineRepository(Supabase.instance.client);
    } catch (_) {
      error =
          'Online setup could not start. Check the app configuration and restart.';
    }
  }
  runApp(
    OnlineApp(
      audience: audience,
      repository: repository,
      startupError: error,
      enableDeepLinks: true,
    ),
  );
}
