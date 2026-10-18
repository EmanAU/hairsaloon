import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_online_repository.dart';
import 'domain/online_models.dart';
import 'online_app.dart';

Future<void> runOnlineApp(AppAudience audience) async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseOnlineRepository? repository;
  String? error;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      final scheme = audience == AppAudience.business
          ? 'com.barbershop.app'
          : 'com.barbershop.app.customer';
      repository = SupabaseOnlineRepository(
        Supabase.instance.client,
        redirectUri: '$scheme://login-callback',
      );
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
